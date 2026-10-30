import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/ubicacion_service.dart';
import 'package:smart_check/viewmodels/beacon_viewmodel.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

void main() {
  late FakeCursoService cursos;
  late FakeBleService ble;
  late FakeUbicacionService ubicacion;
  late BeaconViewModel vm;
  late Curso enAula;

  /// Un llamado abierto de diez minutos, como el que acaba de abrir el
  /// docente.
  Sesion llamadoAbierto({String id = 'llamado-1'}) {
    final ahora = DateTime.now();
    return Sesion(
      id: id,
      inicio: ahora.subtract(const Duration(minutes: 1)),
      fin: ahora.add(const Duration(minutes: 9)),
      bloqueInicio: ahora.subtract(const Duration(minutes: 5)),
    );
  }

  Sesion llamadoVencido() {
    final ahora = DateTime.now();
    return Sesion(
      id: 'vencido',
      inicio: ahora.subtract(const Duration(minutes: 20)),
      fin: ahora.subtract(const Duration(minutes: 10)),
    );
  }

  setUp(() {
    cursos = FakeCursoService();
    enAula = cursoEnClase(geocerca: aula);
    ble = FakeBleService();
    ubicacion = FakeUbicacionService();
    vm = BeaconViewModel(cursos: cursos, ble: ble, ubicacion: ubicacion);
  });

  tearDown(() => vm.dispose());

  test('sin llamado abierto avisa y no anuncia nada', () async {
    expect(await vm.marcar([enAula], '1117000000'), isFalse);

    expect(vm.error, contains('llamado abierto'));
    expect(ble.anunciando, isNull);
    expect(vm.anunciando, isFalse);
  });

  test('un llamado que ya venció tampoco sirve', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoVencido()];

    expect(await vm.marcar([enAula], '1117000000'), isFalse);

    expect(ble.anunciando, isNull);
  });

  test('con el llamado abierto anuncia su clave', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await vm.marcar([enAula], '1117000000'), isTrue);

    expect(vm.anunciando, isTrue);
    expect(ble.anunciando, '1117000000');
    expect(vm.curso!.id, 'c1');
    expect(vm.minutosRestantes, greaterThan(0));
    expect(vm.ventanaVencida, isFalse);
  });

  test('fuera del aula no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    // ~1.1 km al norte del aula.
    ubicacion.posicion = posicionEn(aula.latitud + 0.01, aula.longitud);

    expect(await vm.marcar([enAula], '1117000000'), isFalse);

    expect(vm.error, contains('del aula'));
    expect(ble.anunciando, isNull);
  });

  test('un curso sin aula fijada no exige ubicación', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    ubicacion.fallo = const UbicacionException('sin permiso');

    expect(await vm.marcar([cursoEnClase()], '1117000000'), isTrue);

    expect(ble.anunciando, '1117000000');
  });

  test('parar deja de anunciar', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    await vm.marcar([enAula], '1117000000');

    await vm.parar();

    expect(vm.anunciando, isFalse);
    expect(ble.anunciando, isNull);
    // Lo paró el estudiante, no el reloj.
    expect(vm.ventanaVencida, isFalse);
  });

  test('al acabarse la ventana deja de anunciar solo', () async {
    final ahora = DateTime.now();
    // Una ventana que se cierra en un instante, para no esperar diez minutos.
    cursos.sesionesPorCurso['c1'] = [
      Sesion(
        id: 'llamado-1',
        inicio: ahora.subtract(const Duration(minutes: 1)),
        fin: ahora.add(const Duration(milliseconds: 40)),
      ),
    ];
    await vm.marcar([enAula], '1117000000');
    expect(ble.anunciando, '1117000000');

    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(vm.ventanaVencida, isTrue);
    expect(vm.anunciando, isFalse);
    expect(ble.anunciando, isNull);
    expect(vm.minutosRestantes, 0);
  });

  test('elige la materia cuyo llamado está vigente', () async {
    final otra = cursoEnClase(id: 'c2', geocerca: aula);
    cursos.sesionesPorCurso['c1'] = [llamadoVencido()];
    cursos.sesionesPorCurso['c2'] = [llamadoAbierto(id: 'llamado-2')];

    expect(await vm.marcar([enAula, otra], '1117000000'), isTrue);

    expect(vm.curso!.id, 'c2');
    expect(vm.sesion!.id, 'llamado-2');
  });
}
