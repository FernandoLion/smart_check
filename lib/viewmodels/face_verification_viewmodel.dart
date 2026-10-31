import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/identidad_facial_service.dart';
import '../services/rostro_service.dart';
import '../utils/rostro_vectores.dart';

/// En qué va la verificación facial.
enum PasoVerificacion {
  /// No se ve ninguna cara.
  buscando,

  /// Se ve, pero hay que encuadrarla mejor.
  encuadrando,

  /// Toca hacer el gesto que se pidió.
  reto,

  /// Hizo el gesto: se toma una foto y se compara con la del dueño.
  comparando,

  /// Hecho: el estudiante ya puede emitir la baliza.
  verificado,

  /// No se pudo: se acabó el tiempo o la cara no es la del dueño.
  fallido,
}

/// El gesto que se pide. Se sortea al entrar para que no se pueda preparar
/// un vídeo de antemano.
enum Reto { parpadeo, giro }

/// Cómo se confirmó que es el dueño de la cuenta.
enum ResultadoIdentidad {
  /// Su cara coincide con la referencia guardada en este celular.
  coincide,

  /// No había referencia: su cara coincidió con la foto de Chairá y desde
  /// ahora es la referencia. El docente debería mirarlo dos veces.
  enrolado,
}

/// Lo que la verificación facial le devuelve a quien la abrió.
typedef VerificacionFacial = ({ResultadoIdentidad resultado, double? similitud});

/// ViewModel de la verificación facial: decide si delante de la cámara está
/// el dueño de la cuenta, vivo, antes de dejar emitir la baliza.
///
/// No sabe nada de cámaras ni de ML Kit. Son dos pruebas seguidas:
/// - **De vida**, con lo que ya vio [RostroService]: lo que cierra el fraude
///   no es ver una cara, que una foto también la tiene, sino verla
///   **moverse** cuando se le pide. Por eso el parpadeo exige la secuencia
///   completa de abierto-cerrado-abierto y no un solo fotograma.
/// - **De identidad**, con [IdentidadFacial]: al terminar el gesto la
///   pantalla toma una foto y su cara se compara con la del dueño. Sin esto,
///   un compañero con el celular del ausente pasaría la prueba de vida con
///   su propia cara.
class FaceVerificationViewModel extends ChangeNotifier {
  /// Similitud mínima con la referencia guardada en el celular. Las dos
  /// caras salen de esta misma cámara, así que se puede exigir más.
  /// PENDIENTE: calibrar con pruebas en celulares reales.
  static const umbralIdentidad = 0.50;

  /// Similitud mínima con la foto de Chairá para enrolarse. Es más laxo
  /// porque esa foto puede tener años y otra luz.
  static const umbralEnrolamiento = 0.35;

  /// Fracción del ancho del cuadro que tiene que ocupar la cara. Más lejos,
  /// ni ML Kit ni nadie distingue un parpadeo.
  static const tamanoMinimo = 0.25;

  /// Umbrales de ML Kit para dar un ojo por abierto o por cerrado.
  static const _ojoAbierto = 0.8;
  static const _ojoCerrado = 0.2;

  /// Grados que hay que girar la cabeza, y a partir de cuántos se considera
  /// que ya se volvió a mirar de frente.
  static const _giroPedido = 20.0;
  static const _giroDeFrente = 10.0;

  final Random _azar;

  /// Lo que se le da al estudiante para hacer el gesto antes de darlo por
  /// fallido. Se puede acortar en los tests.
  final Duration limite;

  /// Con quién se compara la cara. null solo en [soloPruebaDeVida].
  final IdentidadFacial? identidad;

  FaceVerificationViewModel({
    required IdentidadFacial this.identidad,
    Random? azar,
    this.limite = const Duration(seconds: 20),
  }) : _azar = azar ?? Random();

  /// Solo el gesto, sin comparar la cara (para probar la prueba de vida).
  FaceVerificationViewModel.soloPruebaDeVida({
    Random? azar,
    this.limite = const Duration(seconds: 20),
  })  : identidad = null,
        _azar = azar ?? Random();

  Timer? _cuentaAtras;
  PasoVerificacion _paso = PasoVerificacion.buscando;
  Reto _reto = Reto.parpadeo;
  String? _aviso;

  // Lo que lleva hecho del gesto.
  bool _vioAbierto = false;
  bool _vioCerrado = false;
  bool _vioGirado = false;

  /// La cara que está haciendo el gesto, según el seguimiento de ML Kit.
  int? _seguimiento;

  bool _comparandoFoto = false;
  ResultadoIdentidad? _resultado;
  double? _similitud;

  PasoVerificacion get paso => _paso;
  Reto get reto => _reto;
  bool get verificado => _paso == PasoVerificacion.verificado;
  bool get terminado => verificado || _paso == PasoVerificacion.fallido;

  /// Si la pantalla tiene que tomar la foto para comparar.
  bool get quiereFoto =>
      _paso == PasoVerificacion.comparando && !_comparandoFoto;

  ResultadoIdentidad? get resultado => _resultado;

  /// La última similitud calculada (para calibrar los umbrales).
  double? get similitudCalculada => _similitud;

  /// Qué parte del gesto lleva hecha, para la barra de la pantalla.
  double get progreso {
    if (verificado || _paso == PasoVerificacion.comparando) return 1;
    if (_reto == Reto.parpadeo) {
      if (_vioCerrado) return 0.66;
      return _vioAbierto ? 0.33 : 0;
    }
    return _vioGirado ? 0.5 : 0;
  }

  /// Lo que hay que decirle al estudiante en cada momento.
  String get instruccion {
    switch (_paso) {
      case PasoVerificacion.buscando:
        return _aviso ?? 'Pon tu cara dentro del círculo.';
      case PasoVerificacion.encuadrando:
        return 'Acércate: tu cara tiene que verse más grande.';
      case PasoVerificacion.reto:
        if (_reto == Reto.parpadeo) {
          if (!_vioAbierto) return 'Mira a la cámara con los ojos abiertos.';
          if (!_vioCerrado) return 'Parpadea.';
          return 'Abre los ojos otra vez.';
        }
        return _vioGirado
            ? 'Vuelve a mirar de frente.'
            : 'Gira la cabeza hacia un lado.';
      case PasoVerificacion.comparando:
        return 'Comparando tu rostro...';
      case PasoVerificacion.verificado:
        return _resultado == ResultadoIdentidad.enrolado
            ? 'Listo, registramos tu rostro en este celular.'
            : 'Listo, eres tú.';
      case PasoVerificacion.fallido:
        return _aviso ?? 'No se pudo verificar tu rostro.';
    }
  }

  /// Arranca (o reintenta) la verificación con un gesto sorteado.
  void empezar() {
    _paso = PasoVerificacion.buscando;
    _reto = _azar.nextBool() ? Reto.parpadeo : Reto.giro;
    _aviso = null;
    _resultado = null;
    _similitud = null;
    _comparandoFoto = false;
    _olvidarElGesto();
    _cuentaAtras?.cancel();
    _cuentaAtras = Timer(limite, _alAgotarseElTiempo);
    notifyListeners();
  }

  /// Lo que se vio en un fotograma. Se llama muchas veces por segundo, así
  /// que solo avisa a la pantalla cuando algo cambia de verdad.
  void alVer(RostroVisto visto) {
    if (terminado || _paso == PasoVerificacion.comparando) return;
    final pasoAntes = _paso;
    final avisoAntes = _aviso;
    final progresoAntes = progreso;

    if (visto.rostros == 0) {
      _paso = PasoVerificacion.buscando;
      _aviso = null;
      _olvidarElGesto();
    } else if (visto.rostros > 1) {
      // Con dos caras en el cuadro no se sabe de quién es el gesto.
      _paso = PasoVerificacion.buscando;
      _aviso = 'Que solo se vea tu cara.';
      _olvidarElGesto();
    } else if (visto.tamano < tamanoMinimo) {
      _paso = PasoVerificacion.encuadrando;
      _aviso = null;
      _olvidarElGesto();
    } else {
      _paso = PasoVerificacion.reto;
      _aviso = null;
      // Si ML Kit dice que la cara es otra, el gesto empieza de cero: no se
      // vale que uno parpadee y otro se ponga para la foto.
      final id = visto.seguimiento;
      if (id != null && _seguimiento != null && id != _seguimiento) {
        _olvidarElGesto();
      }
      _seguimiento = id ?? _seguimiento;
      _avanzarElGesto(visto);
    }

    if (_paso != pasoAntes ||
        _aviso != avisoAntes ||
        progreso != progresoAntes) {
      notifyListeners();
    }
  }

  void _avanzarElGesto(RostroVisto visto) {
    if (_reto == Reto.parpadeo) {
      final izq = visto.ojoIzquierdo;
      final der = visto.ojoDerecho;
      // Si ML Kit no se atreve a decir cómo están los ojos, se espera.
      if (izq == null || der == null) return;
      // Los dos ojos a la vez: guiñar no es parpadear.
      final abiertos = izq >= _ojoAbierto && der >= _ojoAbierto;
      final cerrados = izq <= _ojoCerrado && der <= _ojoCerrado;
      if (!_vioAbierto) {
        _vioAbierto = abiertos;
      } else if (!_vioCerrado) {
        _vioCerrado = cerrados;
      } else if (abiertos) {
        _darPorVerificado();
      }
      return;
    }

    final giro = visto.giroHorizontal?.abs();
    if (giro == null) return;
    if (!_vioGirado) {
      _vioGirado = giro >= _giroPedido;
    } else if (giro <= _giroDeFrente) {
      _darPorVerificado();
    }
  }

  void _darPorVerificado() {
    _cuentaAtras?.cancel();
    _cuentaAtras = null;
    _aviso = null;
    // Sin identidad con qué comparar (solo en las pruebas de la prueba de
    // vida), el gesto basta.
    _paso = identidad == null
        ? PasoVerificacion.verificado
        : PasoVerificacion.comparando;
  }

  /// Compara la cara de la foto que la pantalla tomó al terminar el gesto
  /// con la del dueño de la cuenta.
  ///
  /// Si este celular ya tiene su referencia, se compara con ella. Si no, se
  /// compara con la foto de Chairá y, si coincide, esta cara pasa a ser la
  /// referencia: así un compañero no puede enrolarse en lugar del dueño.
  Future<void> compararFoto(String ruta) async {
    final identidad = this.identidad;
    if (identidad == null || !quiereFoto) return;
    _comparandoFoto = true;
    notifyListeners();
    try {
      final vivo = await identidad.embeddingDeFoto(ruta);
      if (vivo == null) {
        return _fallar('No se vio bien tu cara. Vuelve a intentarlo con '
            'buena luz y sin nadie más en la imagen.');
      }

      final referencia = await identidad.referencia();
      if (referencia != null) {
        _similitud = similitud(vivo, referencia);
        if (_similitud! >= umbralIdentidad) {
          return _confirmar(ResultadoIdentidad.coincide);
        }
        return _fallar('No pudimos confirmar que eres tú. Solo el dueño de '
            'la cuenta puede registrar su asistencia.');
      }

      final chaira = await identidad.embeddingDeChaira();
      if (chaira == null) {
        return _fallar('No hay una foto tuya en Chairá con la que comparar '
            'tu rostro. Pide al docente que te marque a mano.');
      }
      _similitud = similitud(vivo, chaira);
      if (_similitud! < umbralEnrolamiento) {
        return _fallar('Tu rostro no coincide con tu foto de Chairá. Si eres '
            'tú, pide al docente que te marque a mano.');
      }
      await identidad.guardarReferencia(vivo);
      _confirmar(ResultadoIdentidad.enrolado);
    } catch (_) {
      _fallar('No se pudo comparar tu rostro. Vuelve a intentarlo.');
    } finally {
      _comparandoFoto = false;
      notifyListeners();
    }
  }

  void _confirmar(ResultadoIdentidad resultado) {
    _resultado = resultado;
    _paso = PasoVerificacion.verificado;
    _aviso = null;
  }

  void _fallar(String motivo) {
    _paso = PasoVerificacion.fallido;
    _aviso = motivo;
  }

  void _olvidarElGesto() {
    _vioAbierto = false;
    _vioCerrado = false;
    _vioGirado = false;
    _seguimiento = null;
  }

  void _alAgotarseElTiempo() {
    if (terminado) return;
    _cuentaAtras = null;
    _paso = PasoVerificacion.fallido;
    _aviso = 'Se acabó el tiempo. Vuelve a intentarlo.';
    notifyListeners();
  }

  @override
  void dispose() {
    _cuentaAtras?.cancel();
    super.dispose();
  }
}
