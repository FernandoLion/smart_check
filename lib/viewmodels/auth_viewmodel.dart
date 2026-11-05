import 'package:flutter/material.dart';

import '../models/usuario_perfil_model.dart';
import '../services/auth_service.dart';
import '../services/perfil_service.dart';
import '../utils/usuario_input_formatter.dart' as formatter;

/// ViewModel (la VM de MVVM) del inicio de sesión.
///
/// La pantalla no habla con Firebase: le pide las cosas a esta clase y se
/// redibuja cuando esta avisa con [notifyListeners].
class AuthViewModel extends ChangeNotifier {
  static const dominioInstitucional = formatter.dominioInstitucional;

  final AuthService _authService;
  final PerfilService _perfilService;

  /// Los servicios se pueden pasar desde fuera para las pruebas (servicios
  /// falsos en memoria). En la app real se crean los de Firebase.
  AuthViewModel({AuthService? authService, PerfilService? perfilService})
    : _authService = authService ?? AuthService(),
      _perfilService = perfilService ?? PerfilService();

  // Estado privado: solo esta clase lo cambia.
  bool _isLoading = false;
  String? _errorMessage;
  UsuarioPerfil? _perfil;

  // Getters para que las vistas lean el estado sin poder cambiarlo.
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Perfil del usuario con sesión iniciada (null si no hay sesión).
  UsuarioPerfil? get perfil => _perfil;

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

  /// "an.perez@udla.edu.co" -> "an.perez" (en minúsculas y sin espacios).
  static String _usuario(String entrada) {
    final valor = entrada.trim().toLowerCase();
    return valor.endsWith(dominioInstitucional)
        ? valor.substring(0, valor.length - dominioInstitucional.length)
        : valor;
  }

  /// Inicia sesión con Firebase y carga el perfil (y los roles) del usuario.
  /// Devuelve true si entró; si no, el motivo queda en [errorMessage].
  Future<bool> signIn(String usuario, String password) async {
    // 1. Se avisa a la pantalla que empezó la carga (muestra el spinner).
    _isLoading = true;
    _errorMessage = null;
    _perfil = null;
    notifyListeners();

    // 2. Se valida el usuario antes de molestar a Firebase.
    final correo = correoInstitucional(usuario);
    if (correo == null) return _fallar(errorUsuario(usuario)!);

    // 3. Firebase Auth comprueba correo y contraseña.
    final error = await _authService.signInWithEmailPassword(correo, password);
    if (error != null) return _fallar(error);

    // 4. Con la sesión abierta, se lee el perfil en Firestore para saber
    //    quién es y con qué rol entra.
    try {
      final perfil = await _perfilService.obtener(
        _authService.currentUser!.uid,
      );
      if (perfil == null) {
        await _authService.signOut();
        return _fallar('Tu cuenta no tiene un perfil registrado.');
      }
      _perfil = perfil;
    } on PerfilException catch (e) {
      // Sin perfil no se sabe el rol: no se deja la sesión a medias.
      await _authService.signOut();
      return _fallar(e.mensaje);
    }

    // 5. Todo bien: se quita el spinner.
    _isLoading = false;
    notifyListeners();
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
    return true;
  }

  /// Cierra la sesión en Firebase y borra el perfil de memoria.
  Future<void> signOut() async {
    await _authService.signOut();
    _perfil = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Deja el error listo para mostrar, quita el spinner y devuelve false.
  bool _fallar(String mensaje) {
    _isLoading = false;
    _errorMessage = mensaje;
    notifyListeners();
    return false;
  }
}
