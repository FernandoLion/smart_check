import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/usuario_perfil_model.dart';
import '../models/verificacion_result_model.dart';
import '../services/auth_service.dart';
import '../services/chaira_service.dart';
import '../services/dispositivo_service.dart';
import '../services/perfil_service.dart';
import '../utils/usuario_input_formatter.dart' as formatter;

class AuthViewModel extends ChangeNotifier {
  static const dominioInstitucional = formatter.dominioInstitucional;

  final AuthService _authService;
  final ChairaService _chairaService;
  final PerfilService _perfilService;

  final DispositivoService _dispositivos;

  AuthViewModel({
    AuthService? authService,
    ChairaService? chairaService,
    PerfilService? perfilService,
    DispositivoService? dispositivos,
  }) : _authService = authService ?? AuthService(),
       _chairaService = chairaService ?? ChairaService(),
       _perfilService = perfilService ?? PerfilService(),
       _dispositivos = dispositivos ?? DispositivoService();

  bool _isLoading = false;
  bool _isVerifyingChaira = false;
  String? _errorMessage;
  VerificacionResult? _verificacionResult;
  UsuarioPerfil? _perfil;
  Uint8List? _fotoPerfil;

  // Getters para que las Vistas (Screens) lean el estado
  bool get isLoading => _isLoading;
  bool get isVerifyingChaira => _isVerifyingChaira;
  String? get errorMessage => _errorMessage;

  /// Resultado de la última consulta a Chairá (registro o búsqueda de un
  /// estudiante). NO es el usuario logueado: para eso usar [usuarioActual].
  VerificacionResult? get verificacionResult => _verificacionResult;

  /// Perfil del usuario con sesión iniciada (null si no hay sesión).
  UsuarioPerfil? get perfil => _perfil;

  /// Datos del usuario con sesión iniciada para las tarjetas de identidad.
  VerificacionResult? get usuarioActual =>
      _perfil?.comoVerificacion(imagenBytes: _fotoPerfil);

  User? get currentUser => _authService.currentUser;

  /// El celular atado a esta cuenta, o null si todavía no hay ninguno.
  String? get dispositivoVinculado => _perfil?.dispositivoId;

  /// Si este celular es el vinculado. Es lo que mira el marcaje antes de
  /// firmar: el servidor lo vuelve a comprobar, esto solo evita el viaje.
  Future<bool> esEsteDispositivo() async {
    final vinculado = _perfil?.dispositivoId;
    if (vinculado == null || vinculado.isEmpty) return false;
    return await _dispositivos.identificador() == vinculado;
  }

  /// El identificador del celular en el que corre la app, o null si la
  /// plataforma no lo da.
  Future<String?> identificadorDeEsteDispositivo() =>
      _dispositivos.identificador();

  /// Ata el celular en el que corre la app a la cuenta con sesión iniciada.
  ///
  /// Quien la llama (la pantalla del celular vinculado) exige antes que la
  /// cara del estudiante coincida con la suya: eso es lo que impide atar la
  /// cuenta de otro a un teléfono ajeno. No hay espera entre cambios; cada
  /// uno queda en el historial.
  Future<bool> vincularEsteDispositivo() async {
    final perfil = _perfil;
    if (perfil == null) {
      _errorMessage = 'Tu sesión expiró. Vuelve a entrar.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final id = await _dispositivos.identificador();
      if (id == null) {
        _errorMessage =
            'Este dispositivo no da un identificador. La '
            'asistencia se marca desde el celular.';
        return false;
      }
      final desde = await _perfilService.vincularDispositivo(perfil.uid, id);
      _perfil = perfil.conDispositivo(id, desde);
      return true;
    } on PerfilException catch (e) {
      _errorMessage = e.mensaje;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Los celulares por los que ha pasado esta cuenta.
  Future<List<VinculoDispositivo>> historialDeDispositivos() async {
    final perfil = _perfil;
    if (perfil == null) return const [];
    try {
      return await _perfilService.historialDeDispositivos(perfil.uid);
    } on PerfilException {
      return const [];
    }
  }

  /// Solo se usan cuentas @udla.edu.co: el usuario escribe "an.perez" (o el
  /// correo completo) y aquí se valida y se completa a "an.perez@udla.edu.co".
  /// Devuelve null si no es un usuario institucional válido; el motivo queda
  /// en [errorUsuario].
  static String? correoInstitucional(String entrada) {
    return errorUsuario(entrada) == null
        ? '${_usuario(entrada)}$dominioInstitucional'
        : null;
  }

  /// Mensaje que explica por qué [entrada] no es un usuario válido, o null.
  static String? errorUsuario(String entrada) {
    final valor = entrada.trim().toLowerCase();
    if (valor.isEmpty) return 'Escribe tu usuario institucional.';
    if (valor.contains('@') && !valor.endsWith(dominioInstitucional)) {
      return 'Solo se permiten cuentas $dominioInstitucional.';
    }
    if (!formatter.formatoUsuario.hasMatch(_usuario(valor))) {
      return 'Escribe solo tu usuario, por ejemplo an.perez.';
    }
    return null;
  }

  static String _usuario(String entrada) {
    final valor = entrada.trim().toLowerCase();
    return valor.endsWith(dominioInstitucional)
        ? valor.substring(0, valor.length - dominioInstitucional.length)
        : valor;
  }

  /// Limpia errores o datos previos de Chaira (útil al salir de la pantalla de registro)
  void clearState() {
    _errorMessage = null;
    _verificacionResult = null;
    notifyListeners();
  }

  /// 1. Iniciar sesión con Firebase y cargar el perfil (y los roles) del
  /// usuario. Si la cuenta no tiene perfil, [perfil] queda en null y hay que
  /// vincularla con [vincularDocumento].
  Future<bool> signIn(String usuario, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _verificacionResult = null;
    _perfil = null;
    _fotoPerfil = null;
    notifyListeners();

    final correo = correoInstitucional(usuario);
    if (correo == null) return _fallar(errorUsuario(usuario)!);

    final error = await _authService.signInWithEmailPassword(correo, password);
    if (error != null) return _fallar(error);

    try {
      _perfil = await _perfilService.obtener(_authService.currentUser!.uid);
    } on PerfilException catch (e) {
      await _authService.signOut();
      return _fallar(e.mensaje);
    }

    _isLoading = false;
    notifyListeners();
    _cargarFotoPerfil();
    return true;
  }

  /// Si Firebase ya guarda una sesión en este celular, carga su perfil para
  /// entrar sin pedir la contraseña cada vez que se abre la app. Devuelve
  /// false si no hay sesión o si el perfil no se pudo leer: entonces se pide
  /// el ingreso como siempre.
  Future<bool> restaurarSesion() async {
    final usuario = await _authService.sesionGuardada();
    if (usuario == null) return false;
    try {
      final perfil = await _perfilService.obtener(usuario.uid);
      if (perfil == null) return false;
      _perfil = perfil;
    } on PerfilException {
      return false;
    }
    notifyListeners();
    _cargarFotoPerfil();
    return true;
  }

  /// 2. Verificar cédula/documento en Chaira (para smart_register_screen)
  Future<bool> verificarEnChaira(String documento) async {
    _isVerifyingChaira = true;
    _errorMessage = null;
    _verificacionResult = null;
    notifyListeners();

    final result = await _chairaService.verificarDocumento(documento);

    _isVerifyingChaira = false;
    _verificacionResult = result;

    if (!result.success) {
      _errorMessage =
          result.error ?? 'No se pudo verificar el documento en Chaira.';
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// 3. Registrar usuario en Firebase y guardar su perfil verificado en
  /// Chairá. [tambienEstudiante] solo aplica a docentes.
  Future<bool> register(
    String usuario,
    String password, {
    bool tambienEstudiante = false,
  }) async {
    final verificacion = _verificacionResult;
    if (verificacion == null || !verificacion.success) {
      _errorMessage = 'Primero debes verificar tu documento en Chairá.';
      notifyListeners();
      return false;
    }
    final correo = correoInstitucional(usuario);
    if (correo == null) return _fallar(errorUsuario(usuario)!);

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final error = await _authService.registerWithEmailPassword(
      correo,
      password,
    );
    if (error != null) return _fallar(error);

    final perfil = UsuarioPerfil.desdeVerificacion(
      uid: _authService.currentUser!.uid,
      email: correo,
      verificacion: verificacion,
      tambienEstudiante: tambienEstudiante,
    );
    try {
      await _perfilService.guardar(perfil);
    } on PerfilException catch (e) {
      return _fallar(
        'Tu cuenta se creó, pero no se pudo guardar tu perfil. '
        'Inicia sesión para completarlo. (${e.mensaje})',
      );
    }

    _perfil = perfil;
    _fotoPerfil = verificacion.imagenBytes;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Vincula una cuenta sin perfil (creada antes de guardar perfiles) con su
  /// documento. El documento debe corresponder al usuario del correo, para
  /// no poder tomar la identidad ni el rol de otra persona.
  Future<bool> vincularDocumento(String documento) async {
    final user = _authService.currentUser;
    if (user == null) {
      return _fallarVinculacion('Tu sesión expiró. Inicia sesión de nuevo.');
    }

    _isVerifyingChaira = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _chairaService.verificarDocumento(documento);
    if (!result.success) {
      return _fallarVinculacion(
        result.error ?? 'No se pudo verificar el documento en Chairá.',
      );
    }

    final email = (user.email ?? '').toLowerCase();
    final usuarioCorreo = email.split('@').first;
    if (result.username != usuarioCorreo) {
      // Con el usuario que da Chairá esto es una comprobación de verdad; con
      // el deducido del nombre es una aproximación, y conviene decirlo.
      return _fallarVinculacion(
        result.correoVerificado
            ? 'Ese documento está registrado en Chairá con otro usuario, no '
                  'con $email.'
            : 'El documento no corresponde a la cuenta $email.',
      );
    }

    final perfil = UsuarioPerfil.desdeVerificacion(
      uid: user.uid,
      email: email,
      verificacion: result,
    );
    try {
      await _perfilService.guardar(perfil);
    } on PerfilException catch (e) {
      return _fallarVinculacion(e.mensaje);
    }

    _perfil = perfil;
    _fotoPerfil = result.imagenBytes;
    _isVerifyingChaira = false;
    notifyListeners();
    return true;
  }

  /// 4. Recuperar contraseña
  Future<bool> recoverPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final correo = correoInstitucional(email);
    if (correo == null) return _fallar(errorUsuario(email)!);

    final error = await _authService.recoverPassword(correo);
    if (error != null) return _fallar(error);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// 5. Cerrar sesión
  Future<void> signOut() async {
    await _authService.signOut();
    _perfil = null;
    _fotoPerfil = null;
    _verificacionResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  bool _fallar(String mensaje) {
    _isLoading = false;
    _errorMessage = mensaje;
    notifyListeners();
    return false;
  }

  bool _fallarVinculacion(String mensaje) {
    _isVerifyingChaira = false;
    _errorMessage = mensaje;
    notifyListeners();
    return false;
  }

  /// Esperas entre intentos de bajar la foto. Chairá a veces tarda más de
  /// lo que aguanta una descarga (8 s), sobre todo en la primera consulta
  /// del día; con un solo intento la foto se quedaba sin cargar.
  static const _esperasFoto = [
    Duration.zero,
    Duration(seconds: 3),
    Duration(seconds: 10),
  ];

  /// La foto no se guarda en la base de datos: se descarga de Chairá.
  Future<void> _cargarFotoPerfil() async {
    final perfil = _perfil;
    if (perfil?.fotoUrl == null) return;
    for (final espera in _esperasFoto) {
      await Future<void>.delayed(espera);
      // Cerró sesión o entró con otra cuenta mientras tanto.
      if (!identical(_perfil, perfil)) return;
      final bytes = await _chairaService.descargarFoto(perfil!.fotoUrl!);
      if (bytes != null && identical(_perfil, perfil)) {
        _fotoPerfil = bytes;
        notifyListeners();
        return;
      }
    }
  }

  @override
  void dispose() {
    _chairaService.dispose();
    super.dispose();
  }
}
