import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/services/rostro_service.dart';
import 'package:smart_check/viewmodels/face_verification_viewmodel.dart';

/// Un `Random` que siempre contesta lo mismo, para elegir el gesto en los
/// tests en vez de dejarlo al azar.
class _AzarFijo implements Random {
  _AzarFijo(this.valor);
  final bool valor;

  @override
  bool nextBool() => valor;

  @override
  double nextDouble() => valor ? 1 : 0;

  @override
  int nextInt(int max) => valor ? max - 1 : 0;
}

/// Una cara bien encuadrada, con los ojos como se le diga.
RostroVisto cara({
  double ojos = 1,
  double giro = 0,
  double tamano = 0.4,
  int rostros = 1,
}) =>
    RostroVisto(
      rostros: rostros,
      tamano: tamano,
      ojoIzquierdo: ojos,
      ojoDerecho: ojos,
      giroHorizontal: giro,
    );

void main() {
  /// El viewmodel con el gesto ya elegido: `nextBool` true es parpadeo.
  FaceVerificationViewModel conReto(Reto reto, {Duration? limite}) {
    final vm = FaceVerificationViewModel(
      azar: _AzarFijo(reto == Reto.parpadeo),
      limite: limite ?? const Duration(seconds: 20),
    );
    addTearDown(vm.dispose);
    vm.empezar();
    expect(vm.reto, reto);
    return vm;
  }

  test('sin nadie delante no verifica', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(RostroVisto.nadie);

    expect(vm.paso, PasoVerificacion.buscando);
    expect(vm.verificado, isFalse);
  });

  test('con dos caras en el cuadro no verifica', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(cara(rostros: 2));

    expect(vm.paso, PasoVerificacion.buscando);
    expect(vm.instruccion, contains('solo se vea tu cara'));
  });

  test('una cara demasiado lejos pide acercarse', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(cara(tamano: FaceVerificationViewModel.tamanoMinimo - 0.01));

    expect(vm.paso, PasoVerificacion.encuadrando);
    expect(vm.instruccion, contains('Acércate'));
  });

  test('el parpadeo completo verifica', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(cara(ojos: 0.95));
    expect(vm.paso, PasoVerificacion.reto);
    expect(vm.instruccion, 'Parpadea.');
    vm.alVer(cara(ojos: 0.05));
    expect(vm.instruccion, contains('Abre los ojos'));
    vm.alVer(cara(ojos: 0.95));

    expect(vm.verificado, isTrue);
    expect(vm.progreso, 1);
  });

  test('una foto con los ojos abiertos no pasa el parpadeo', () {
    final vm = conReto(Reto.parpadeo);

    // Mil fotogramas iguales, como los de una foto impresa delante de la
    // cámara: sin la secuencia completa no hay prueba de vida.
    for (var i = 0; i < 1000; i++) {
      vm.alVer(cara(ojos: 0.95));
    }

    expect(vm.verificado, isFalse);
    expect(vm.paso, PasoVerificacion.reto);
  });

  test('cerrar los ojos de entrada tampoco basta', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(cara(ojos: 0.05));
    vm.alVer(cara(ojos: 0.05));

    expect(vm.verificado, isFalse);
  });

  test('guiñar un ojo no es parpadear', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(cara(ojos: 0.95));
    vm.alVer(const RostroVisto(
      rostros: 1,
      tamano: 0.4,
      ojoIzquierdo: 0.05,
      ojoDerecho: 0.95,
    ));
    vm.alVer(cara(ojos: 0.95));

    expect(vm.verificado, isFalse);
  });

  test('si no se sabe cómo están los ojos, se espera', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(const RostroVisto(rostros: 1, tamano: 0.4));

    expect(vm.paso, PasoVerificacion.reto);
    expect(vm.progreso, 0);
  });

  test('girar la cabeza y volver verifica', () {
    final vm = conReto(Reto.giro);

    // Hasta que no hay una cara encuadrada, lo que se pide es encuadrarla.
    expect(vm.instruccion, contains('dentro del círculo'));
    vm.alVer(cara(giro: 0));
    expect(vm.instruccion, contains('Gira la cabeza'));
    vm.alVer(cara(giro: -25));
    expect(vm.instruccion, contains('de frente'));
    vm.alVer(cara(giro: 2));

    expect(vm.verificado, isTrue);
  });

  test('quedarse de frente no pasa el giro', () {
    final vm = conReto(Reto.giro);

    for (var i = 0; i < 100; i++) {
      vm.alVer(cara(giro: 3));
    }

    expect(vm.verificado, isFalse);
  });

  test('si la cara se va a media prueba, el gesto empieza de nuevo', () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(cara(ojos: 0.95));
    vm.alVer(cara(ojos: 0.05));
    vm.alVer(RostroVisto.nadie);
    // Volver con los ojos abiertos ya no cierra el parpadeo de antes.
    vm.alVer(cara(ojos: 0.95));

    expect(vm.verificado, isFalse);
    expect(vm.instruccion, 'Parpadea.');
  });

  test('se acaba el tiempo y falla', () async {
    final vm = conReto(
      Reto.parpadeo,
      limite: const Duration(milliseconds: 30),
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(vm.paso, PasoVerificacion.fallido);
    expect(vm.instruccion, contains('tiempo'));
    // Y ya no reacciona a nada hasta que se reintente.
    vm.alVer(cara(ojos: 0.95));
    expect(vm.paso, PasoVerificacion.fallido);
  });

  test('reintentar vuelve a empezar', () async {
    final vm = conReto(
      Reto.parpadeo,
      limite: const Duration(milliseconds: 30),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(vm.paso, PasoVerificacion.fallido);

    vm.empezar();

    expect(vm.paso, PasoVerificacion.buscando);
    expect(vm.terminado, isFalse);
    expect(vm.progreso, 0);
  });
}
