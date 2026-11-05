import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/services/identidad_facial_service.dart';
import 'package:smart_check/services/rostro_service.dart';
import 'package:smart_check/viewmodels/face_verification_viewmodel.dart';

/// Caras de mentira: cada "foto" es un vector fijo según su ruta.
class _IdentidadFalsa implements IdentidadFacial {
  final Map<String, List<double>?> fotos;
  List<double>? guardada;
  List<double>? chaira;
  bool falla = false;

  _IdentidadFalsa({required this.fotos, this.guardada, this.chaira});

  @override
  Future<List<double>?> embeddingDeFoto(String ruta) async {
    if (falla) throw Exception('sin modelo');
    return fotos[ruta];
  }

  @override
  Future<List<double>?> referencia() async => guardada;

  @override
  Future<void> guardarReferencia(List<double> embedding) async =>
      guardada = embedding;

  /// Lo que la verificación le ofreció para afinar la referencia.
  final ofrecidas = <List<double>>[];

  @override
  Future<bool> aprender(List<double> embedding) async {
    ofrecidas.add(embedding);
    return true;
  }

  @override
  Future<List<double>?> embeddingDeChaira() async => chaira;

  @override
  Future<void> cerrar() async {}
}

// Vectores con similitudes conocidas: el coseno entre dueno y casiDueno es
// 0.8, y entre dueno y otro es 0.
const dueno = [1.0, 0.0];
const casiDueno = [0.8, 0.6];
const otro = [0.0, 1.0];

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
    final vm = FaceVerificationViewModel.soloPruebaDeVida(
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

  test('si otra cara toma el lugar a media prueba, el gesto empieza de nuevo',
      () {
    final vm = conReto(Reto.parpadeo);

    vm.alVer(const RostroVisto(
      rostros: 1, tamano: 0.4, ojoIzquierdo: 0.95, ojoDerecho: 0.95,
      seguimiento: 1,
    ));
    vm.alVer(const RostroVisto(
      rostros: 1, tamano: 0.4, ojoIzquierdo: 0.05, ojoDerecho: 0.05,
      seguimiento: 1,
    ));
    // Otra persona (otro id de seguimiento) abre los ojos.
    vm.alVer(const RostroVisto(
      rostros: 1, tamano: 0.4, ojoIzquierdo: 0.95, ojoDerecho: 0.95,
      seguimiento: 2,
    ));

    expect(vm.verificado, isFalse);
    expect(vm.instruccion, 'Parpadea.');
  });

  group('identidad', () {
    FaceVerificationViewModel conIdentidad(
      _IdentidadFalsa identidad, {
      MotivoVerificacion motivo = MotivoVerificacion.asistencia,
    }) {
      final vm = FaceVerificationViewModel(
        identidad: identidad,
        motivo: motivo,
        azar: _AzarFijo(true),
      );
      addTearDown(vm.dispose);
      vm.empezar();
      // El parpadeo completo.
      vm.alVer(cara(ojos: 0.95));
      vm.alVer(cara(ojos: 0.05));
      vm.alVer(cara(ojos: 0.95));
      return vm;
    }

    test('tras el gesto pide la foto en vez de dar por verificado', () {
      final vm = conIdentidad(_IdentidadFalsa(fotos: {}));

      expect(vm.paso, PasoVerificacion.comparando);
      expect(vm.quiereFoto, isTrue);
      expect(vm.verificado, isFalse);
      // Mientras compara, los fotogramas ya no cuentan.
      vm.alVer(RostroVisto.nadie);
      expect(vm.paso, PasoVerificacion.comparando);
    });

    test('el dueño con referencia pasa', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': casiDueno}, guardada: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.verificado, isTrue);
      expect(vm.resultado, ResultadoIdentidad.coincide);
      expect(vm.similitudCalculada, closeTo(0.8, 1e-9));
    });

    test('otra persona con el celular del dueño no pasa', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': otro}, guardada: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('No pudimos confirmar que eres tú'));
      // Fallar no toca la referencia ni le enseña nada.
      expect(identidad.guardada, dueno);
      expect(identidad.ofrecidas, isEmpty);
    });

    test('una verificación buena se ofrece para afinar la referencia',
        () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': casiDueno}, guardada: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(identidad.ofrecidas, [casiDueno]);
    });

    test('enrolarse empieza la referencia, no la afina', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': casiDueno}, chaira: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(identidad.guardada, casiDueno);
      expect(identidad.ofrecidas, isEmpty);
    });

    test('sin referencia se enrola si coincide con Chairá', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': casiDueno}, chaira: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.verificado, isTrue);
      expect(vm.resultado, ResultadoIdentidad.enrolado);
      expect(identidad.guardada, casiDueno);
      expect(vm.instruccion, contains('registramos tu rostro'));
    });

    test('al crear la cuenta, un rostro ajeno no habla del docente',
        () async {
      // Lo que pasó probando: crear una cuenta con la cara de un amigo
      // terminaba en "pide al docente que te marque a mano".
      final identidad = _IdentidadFalsa(fotos: {'foto': otro}, chaira: dueno);
      final vm = conIdentidad(identidad, motivo: MotivoVerificacion.registro);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('Solo su dueño puede crear la cuenta'));
      expect(vm.instruccion, isNot(contains('docente')));
      expect(identidad.guardada, isNull);
    });

    test('desde Ajustes tampoco: no hay llamado que marcar a mano', () async {
      final ajena = _IdentidadFalsa(fotos: {'foto': otro}, chaira: dueno);
      final conReferencia =
          _IdentidadFalsa(fotos: {'foto': otro}, guardada: dueno);

      final enrolando = conIdentidad(ajena, motivo: MotivoVerificacion.cuenta);
      await enrolando.compararFoto('foto');
      final probando =
          conIdentidad(conReferencia, motivo: MotivoVerificacion.cuenta);
      await probando.compararFoto('foto');

      for (final vm in [enrolando, probando]) {
        expect(vm.paso, PasoVerificacion.fallido);
        expect(vm.instruccion, isNot(contains('docente')));
        expect(vm.instruccion, isNot(contains('asistencia')));
      }
    });

    test('el docente dueño de la cuenta abre el llamado', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': casiDueno}, guardada: dueno);
      final vm = conIdentidad(identidad, motivo: MotivoVerificacion.llamado);

      await vm.compararFoto('foto');

      expect(vm.verificado, isTrue);
      expect(vm.resultado, ResultadoIdentidad.coincide);
    });

    test('otra persona con el celular del docente no abre el llamado',
        () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': otro}, guardada: dueno);
      final vm = conIdentidad(identidad, motivo: MotivoVerificacion.llamado);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('Solo el docente dueño de la cuenta'));
      // Al docente no se le dice que lo marquen a mano.
      expect(vm.instruccion, isNot(contains('a mano')));
      expect(identidad.guardada, dueno);
    });

    test('el docente sin referencia se enrola contra su foto de Chairá',
        () async {
      final bien = _IdentidadFalsa(fotos: {'foto': casiDueno}, chaira: dueno);
      final mal = _IdentidadFalsa(fotos: {'foto': otro}, chaira: dueno);

      final enrolado = conIdentidad(bien, motivo: MotivoVerificacion.llamado);
      await enrolado.compararFoto('foto');
      final rechazado = conIdentidad(mal, motivo: MotivoVerificacion.llamado);
      await rechazado.compararFoto('foto');

      expect(enrolado.resultado, ResultadoIdentidad.enrolado);
      expect(bien.guardada, isNotNull);
      expect(rechazado.paso, PasoVerificacion.fallido);
      expect(rechazado.instruccion, isNot(contains('a mano')));
      expect(mal.guardada, isNull);
    });

    test('un compañero no se puede enrolar en lugar del dueño', () async {
      final identidad = _IdentidadFalsa(fotos: {'foto': otro}, chaira: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('no coincide con tu foto de Chairá'));
      expect(identidad.guardada, isNull);
    });

    test('sin foto de Chairá no se puede enrolar', () async {
      final identidad = _IdentidadFalsa(fotos: {'foto': dueno});
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('marque a mano'));
      expect(identidad.guardada, isNull);
    });

    test('si en la foto no hay una sola cara, falla', () async {
      final identidad = _IdentidadFalsa(fotos: {'foto': null}, guardada: dueno);
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('No se vio bien tu cara'));
    });

    test('un error del modelo falla sin romper la pantalla', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': dueno}, guardada: dueno)
            ..falla = true;
      final vm = conIdentidad(identidad);

      await vm.compararFoto('foto');

      expect(vm.paso, PasoVerificacion.fallido);
      expect(vm.instruccion, contains('No se pudo comparar'));
    });

    test('reintentar después de fallar vuelve a pedir el gesto', () async {
      final identidad =
          _IdentidadFalsa(fotos: {'foto': otro}, guardada: dueno);
      final vm = conIdentidad(identidad);
      await vm.compararFoto('foto');

      vm.empezar();

      expect(vm.paso, PasoVerificacion.buscando);
      expect(vm.resultado, isNull);
      expect(vm.quiereFoto, isFalse);
    });
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
