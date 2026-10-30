import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/rostro_service.dart';

/// En qué va la verificación facial.
enum PasoVerificacion {
  /// No se ve ninguna cara.
  buscando,

  /// Se ve, pero hay que encuadrarla mejor.
  encuadrando,

  /// Toca hacer el gesto que se pidió.
  reto,

  /// Hecho: el estudiante ya puede emitir la baliza.
  verificado,

  /// No se pudo, porque se acabó el tiempo.
  fallido,
}

/// El gesto que se pide. Se sortea al entrar para que no se pueda preparar
/// un vídeo de antemano.
enum Reto { parpadeo, giro }

/// ViewModel de la verificación facial: decide si delante de la cámara hay
/// una persona de verdad antes de dejar emitir la baliza.
///
/// No sabe nada de cámaras ni de ML Kit: recibe lo que ya vio
/// [RostroService] y lleva la cuenta del gesto. Lo que cierra el fraude no es
/// ver una cara, que una foto también la tiene, sino verla **moverse** cuando
/// se le pide: por eso el parpadeo exige la secuencia completa de
/// abierto-cerrado-abierto y no un solo fotograma.
class FaceVerificationViewModel extends ChangeNotifier {
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

  FaceVerificationViewModel({
    Random? azar,
    this.limite = const Duration(seconds: 20),
  }) : _azar = azar ?? Random();

  Timer? _cuentaAtras;
  PasoVerificacion _paso = PasoVerificacion.buscando;
  Reto _reto = Reto.parpadeo;
  String? _aviso;

  // Lo que lleva hecho del gesto.
  bool _vioAbierto = false;
  bool _vioCerrado = false;
  bool _vioGirado = false;

  PasoVerificacion get paso => _paso;
  Reto get reto => _reto;
  bool get verificado => _paso == PasoVerificacion.verificado;
  bool get terminado => verificado || _paso == PasoVerificacion.fallido;

  /// Qué parte del gesto lleva hecha, para la barra de la pantalla.
  double get progreso {
    if (verificado) return 1;
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
      case PasoVerificacion.verificado:
        return 'Listo, eres tú.';
      case PasoVerificacion.fallido:
        return _aviso ?? 'No se pudo verificar tu rostro.';
    }
  }

  /// Arranca (o reintenta) la verificación con un gesto sorteado.
  void empezar() {
    _paso = PasoVerificacion.buscando;
    _reto = _azar.nextBool() ? Reto.parpadeo : Reto.giro;
    _aviso = null;
    _olvidarElGesto();
    _cuentaAtras?.cancel();
    _cuentaAtras = Timer(limite, _alAgotarseElTiempo);
    notifyListeners();
  }

  /// Lo que se vio en un fotograma. Se llama muchas veces por segundo, así
  /// que solo avisa a la pantalla cuando algo cambia de verdad.
  void alVer(RostroVisto visto) {
    if (terminado) return;
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
    _paso = PasoVerificacion.verificado;
    _aviso = null;
  }

  void _olvidarElGesto() {
    _vioAbierto = false;
    _vioCerrado = false;
    _vioGirado = false;
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
