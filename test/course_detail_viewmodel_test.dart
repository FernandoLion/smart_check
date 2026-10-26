import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/curso_service.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';

import 'curso_fakes.dart';

Asistencia presente(String clave) => Asistencia(
      claveInscrito: clave,
      estado: EstadoAsistencia.presente,
      metodo: MetodoAsistencia.ble,
      hora: DateTime(2026, 10, 20, 8, 5),
      registradoPor: 'uid-docente',
    );

Asistencia ausente(String clave) => Asistencia(
      claveInscrito: clave,
      estado: EstadoAsistencia.ausente,
      metodo: MetodoAsistencia.manual,
      hora: DateTime(2026, 10, 20, 8, 5),
      registradoPor: 'uid-docente',
    );

Sesion sesion(String id, int dia, {bool abierta = false}) => Sesion(
      id: id,
      inicio: DateTime(2026, 10, dia, 8),
      fin: DateTime(2026, 10, dia, 10),
      abierta: abierta,
    );

void main() {
  late FakeCursoService servicio;
  late CourseDetailViewModel vm;

  setUp(() {
    servicio = FakeCursoService();
    servicio.inscritosPorCurso['c1'] = {
      'ana': const Inscrito(cedula: 'ana', nombre: 'ANA PÉREZ'),
      'carlos': const Inscrito(cedula: 'carlos', nombre: 'CARLOS MUÑOZ'),
    };
    vm = CourseDetailViewModel(servicio: servicio);
  });

  tearDown(() => vm.dispose());

  test('sin sesiones no juzga a nadie', () async {
    vm.vigilar('c1');
    await pumpEventQueue();

    expect(vm.cargando, isFalse);
    expect(vm.totalInscritos, 2);
    expect(vm.sesionesPasadas, isEmpty);
    expect(vm.enRiesgo, 0);
    expect(vm.promedio.porcentaje, isNull);
    expect(vm.inscritos.every((i) => i.asistencia.porcentaje == null), isTrue);
  });

  test('cuenta la asistencia de cada sesión y de cada inscrito', () async {
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 6), sesion('s2', 8)];
    servicio.asistenciasPorSesion['s1'] = [
      presente('ana'),
      presente('carlos'),
    ];
    servicio.asistenciasPorSesion['s2'] = [presente('ana'), ausente('carlos')];

    vm.vigilar('c1');
    await pumpEventQueue();

    // La más reciente primero.
    expect(vm.sesionesPasadas.map((s) => s.sesion.id), ['s2', 's1']);
    expect(vm.sesionesPasadas.first.asistieron, 1);
    expect(vm.sesionesPasadas.first.porcentaje, 50);
    expect(vm.sesionesPasadas.first.bajaAsistencia, isTrue);
    expect(vm.sesionesPasadas.last.porcentaje, 100);

    // Los de más riesgo primero.
    expect(vm.inscritos.map((i) => i.nombre), ['CARLOS MUÑOZ', 'ANA PÉREZ']);
    expect(vm.inscritos.first.asistencia.porcentaje, 50);
    expect(vm.inscritos.first.asistencia.nivel, NivelAsistencia.riesgo);
    expect(vm.inscritos.last.asistencia.porcentaje, 100);
    expect(vm.enRiesgo, 1);
    expect(vm.promedio.porcentaje, 75);
  });

  test('la sesión abierta no cuenta como falta todavía', () async {
    servicio.sesionesPorCurso['c1'] = [
      sesion('s1', 6),
      sesion('s2', 26, abierta: true),
    ];
    servicio.asistenciasPorSesion['s1'] = [
      presente('ana'),
      presente('carlos'),
    ];

    vm.vigilar('c1');
    await pumpEventQueue();

    expect(vm.sesionAbierta?.id, 's2');
    expect(vm.sesionesPasadas.map((s) => s.sesion.id), ['s1']);
    expect(vm.inscritos.every((i) => i.asistencia.sesiones == 1), isTrue);
    expect(vm.promedio.porcentaje, 100);
  });

  test('informa el error si no se pueden leer las asistencias', () async {
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 6)];
    servicio.fallo = const CursoException('permiso denegado');

    vm.vigilar('c1');
    await pumpEventQueue();

    expect(vm.error, 'permiso denegado');
    // Los inscritos y las sesiones se siguen viendo.
    expect(vm.totalInscritos, 2);
    expect(vm.sesionesPasadas, hasLength(1));
  });
}
