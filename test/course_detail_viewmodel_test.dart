import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/curso_model.dart';
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

/// Un llamado de diez minutos dentro del bloque de las 8 del día [dia].
Sesion llamado(
  String id,
  int dia,
  int minuto, {
  bool abierta = false,
}) =>
    Sesion(
      id: id,
      inicio: DateTime(2026, 10, dia, 8, minuto),
      fin: DateTime(2026, 10, dia, 8, minuto + 10),
      abierta: abierta,
      bloqueInicio: DateTime(2026, 10, dia, 8),
    );

/// Media mañana del 26, para que las clases anteriores ya sean pasado y la
/// del 26 esté en curso.
DateTime get elLunes26 => DateTime(2026, 10, 26, 9);

void main() {
  late FakeCursoService servicio;
  late CourseDetailViewModel vm;

  setUp(() {
    servicio = FakeCursoService();
    servicio.inscritosPorCurso['c1'] = {
      'ana': const Inscrito(cedula: 'ana', nombre: 'ANA PÉREZ'),
      'carlos': const Inscrito(cedula: 'carlos', nombre: 'CARLOS MUÑOZ'),
    };
    vm = CourseDetailViewModel(servicio: servicio, reloj: () => elLunes26);
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

  test('exporta la asistencia en CSV: una columna por clase', () async {
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 6), sesion('s2', 8)];
    servicio.asistenciasPorSesion['s1'] = [
      presente('ana'),
      presente('carlos'),
    ];
    servicio.asistenciasPorSesion['s2'] = [presente('ana'), ausente('carlos')];

    vm.vigilar('c1');
    await pumpEventQueue();

    expect(vm.asistenciaEnCsv().split('\n'), [
      'Estudiante;Identificación;2026-10-06;2026-10-08;Asistidas;Porcentaje',
      'ANA PÉREZ;ana;A;A;2/2;100%',
      'CARLOS MUÑOZ;carlos;A;F;1/2;50%',
    ]);
  });

  test('a quien inscriben tarde no le cuentan las clases de antes', () async {
    // Pedro entra el 7: la clase del 6 ya pasó, la del 8 sí le toca.
    servicio.inscritosPorCurso['c1']!['pedro'] = Inscrito(
      cedula: 'pedro',
      nombre: 'PEDRO TARDE',
      inscritoEn: DateTime(2026, 10, 7, 12),
    );
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 6), sesion('s2', 8)];
    servicio.asistenciasPorSesion['s1'] = [presente('ana')];
    servicio.asistenciasPorSesion['s2'] = [presente('ana'), presente('pedro')];

    vm.vigilar('c1');
    await pumpEventQueue();

    final pedro = vm.inscritos.firstWhere((i) => i.inscrito.clave == 'pedro');
    expect(pedro.asistencia.sesiones, 1);
    expect(pedro.asistencia.porcentaje, 100);
    // Al que sí estaba desde el principio le cuentan las dos.
    final carlos =
        vm.inscritos.firstWhere((i) => i.inscrito.clave == 'carlos');
    expect(carlos.asistencia.sesiones, 2);

    // La clase del 6 era de dos inscritos, no de tres.
    final del6 = vm.sesionesPasadas.firstWhere((s) => s.sesion.id == 's1');
    expect(del6.inscritos, 2);
    expect(
      vm.detalleDeFranja(DateTime(2026, 10, 6, 8)).map((f) => f.inscrito.clave),
      isNot(contains('pedro')),
    );
    expect(
      vm.asistenciaEnCsv().split('\n'),
      contains('PEDRO TARDE;pedro;—;A;1/1;100%'),
    );

    // El panel docente saca la misma cuenta.
    final resumen = CursoService.promedioDe(
      servicio.inscritosPorCurso['c1']!.values.toList(),
      CursoService.franjasTerminadas(
        servicio.sesionesPorCurso['c1']!,
        elLunes26,
      ),
      servicio.asistenciasPorSesion,
    );
    expect(resumen.porcentaje, vm.promedio.porcentaje);
  });

  test('si vino a una clase de antes de inscribirlo, le cuenta a favor',
      () async {
    servicio.inscritosPorCurso['c1']!['pedro'] = Inscrito(
      cedula: 'pedro',
      nombre: 'PEDRO TARDE',
      inscritoEn: DateTime(2026, 10, 7, 12),
    );
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 6), sesion('s2', 8)];
    servicio.asistenciasPorSesion['s1'] = [presente('pedro')];

    vm.vigilar('c1');
    await pumpEventQueue();

    final pedro = vm.inscritos.firstWhere((i) => i.inscrito.clave == 'pedro');
    expect(pedro.asistencia.asistidas, 1);
    expect(pedro.asistencia.sesiones, 2);
  });

  test('volver a inscribir a alguien no le cambia la fecha', () async {
    servicio.cursos['c1'] = Curso.fromMap('c1', {
      'codigo': 'X',
      'nombre': 'Curso',
      'docente_uid': 'uid-docente',
      'claves_inscritos': <String>[],
    });
    servicio.relojInscripcion = () => DateTime(2026, 10, 7);
    await servicio.inscribir('c1', [
      const Inscrito(cedula: 'pedro', nombre: 'PEDRO'),
    ]);
    servicio.relojInscripcion = () => DateTime(2026, 10, 20);
    await servicio.inscribir('c1', [
      const Inscrito(cedula: 'pedro', nombre: 'PEDRO'),
    ]);

    expect(
      servicio.inscritosPorCurso['c1']!['pedro']!.inscritoEn,
      DateTime(2026, 10, 7),
    );
  });

  test('el promedio del panel docente es el mismo del detalle', () async {
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 6), sesion('s2', 8)];
    servicio.asistenciasPorSesion['s1'] = [
      presente('ana'),
      presente('carlos'),
    ];
    servicio.asistenciasPorSesion['s2'] = [presente('ana'), ausente('carlos')];

    vm.vigilar('c1');
    await pumpEventQueue();
    final franjas = CursoService.franjasTerminadas(
      servicio.sesionesPorCurso['c1']!,
      elLunes26,
    );
    final resumen = CursoService.promedioDe(
      servicio.inscritosPorCurso['c1']!.values.toList(),
      franjas,
      servicio.asistenciasPorSesion,
    );

    expect(resumen.porcentaje, vm.promedio.porcentaje);
    expect(resumen.porcentaje, 75);
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

    expect(vm.llamadoVigente?.id, 's2');
    expect(vm.sesionesPasadas.map((s) => s.sesion.id), ['s1']);
    expect(vm.inscritos.every((i) => i.asistencia.sesiones == 1), isTrue);
    expect(vm.promedio.porcentaje, 100);
  });

  test('un llamado abierto que ya venció cuenta como clase pasada', () async {
    // Quedó abierto el día anterior porque al docente se le murió la app.
    servicio.sesionesPorCurso['c1'] = [sesion('s1', 25, abierta: true)];
    servicio.asistenciasPorSesion['s1'] = [presente('ana')];

    vm.vigilar('c1');
    await pumpEventQueue();

    expect(vm.llamadoVigente, isNull);
    expect(vm.sesionesPasadas.map((s) => s.sesion.id), ['s1']);
    expect(vm.promedio.porcentaje, 50);
  });

  test('dos llamados de la misma franja son una sola clase', () async {
    // El docente abrió el radar dos veces en el mismo bloque.
    servicio.sesionesPorCurso['c1'] = [llamado('s1', 20, 2), llamado('s2', 20, 40)];
    servicio.asistenciasPorSesion['s1'] = [presente('ana')];
    servicio.asistenciasPorSesion['s2'] = [presente('carlos')];

    vm.vigilar('c1');
    await pumpEventQueue();

    expect(vm.sesionesPasadas, hasLength(1));
    // Quien apareció en cualquiera de los dos llamados asistió a la clase.
    expect(vm.sesionesPasadas.single.asistieron, 2);
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

  group('detalle de una clase', () {
    final franja20 = DateTime(2026, 10, 20, 8);

    test('lista a los inscritos reales: presentes primero, por hora', () async {
      servicio.sesionesPorCurso['c1'] = [llamado('s1', 20, 2)];
      servicio.asistenciasPorSesion['s1'] = [presente('carlos')];

      vm.vigilar('c1');
      await pumpEventQueue();
      final filas = vm.detalleDeFranja(franja20);

      expect(filas.map((f) => f.inscrito.nombre), ['CARLOS MUÑOZ', 'ANA PÉREZ']);
      expect(filas.first.presente, isTrue);
      expect(filas.first.marca!.metodo, MetodoAsistencia.ble);
      expect(filas.last.presente, isFalse);
      expect(filas.last.marca, isNull);
    });

    test('con dos llamados en la franja, cuenta la marca que asistió',
        () async {
      servicio.sesionesPorCurso['c1'] = [
        llamado('s1', 20, 2),
        llamado('s2', 20, 40),
      ];
      servicio.asistenciasPorSesion['s1'] = [ausente('ana')];
      servicio.asistenciasPorSesion['s2'] = [presente('ana')];

      vm.vigilar('c1');
      await pumpEventQueue();
      final ana = vm
          .detalleDeFranja(franja20)
          .firstWhere((f) => f.inscrito.clave == 'ana');

      expect(ana.presente, isTrue);
    });

    test('marcar presente a mano se guarda y se ve sin recargar', () async {
      servicio.sesionesPorCurso['c1'] = [llamado('s1', 20, 2)];

      vm.vigilar('c1');
      await pumpEventQueue();
      final ana = vm.detalleDeFranja(franja20).firstWhere(
            (f) => f.inscrito.clave == 'ana',
          );
      final error = await vm.corregirAsistencia(
        franja20,
        ana.inscrito,
        presente: true,
        docenteUid: 'uid-docente',
      );

      expect(error, isNull);
      final guardada = servicio.asistenciasPorSesion['s1']!.single;
      expect(guardada.claveInscrito, 'ana');
      expect(guardada.metodo, MetodoAsistencia.manual);
      expect(guardada.registradoPor, 'uid-docente');
      expect(
        vm.detalleDeFranja(franja20).firstWhere((f) => f.inscrito.clave == 'ana').presente,
        isTrue,
      );
      expect(vm.sesionesPasadas.single.asistieron, 1);
    });

    test('dejarlo ausente corrige cada llamado donde contaba', () async {
      servicio.sesionesPorCurso['c1'] = [
        llamado('s1', 20, 2),
        llamado('s2', 20, 40),
      ];
      servicio.asistenciasPorSesion['s1'] = [presente('ana')];
      servicio.asistenciasPorSesion['s2'] = [presente('ana')];

      vm.vigilar('c1');
      await pumpEventQueue();
      final ana = vm.detalleDeFranja(franja20).first.inscrito;
      await vm.corregirAsistencia(
        franja20,
        ana,
        presente: false,
        docenteUid: 'uid-docente',
      );

      for (final id in ['s1', 's2']) {
        final marca = servicio.asistenciasPorSesion[id]!.single;
        expect(marca.estado, EstadoAsistencia.ausente);
        expect(marca.metodo, MetodoAsistencia.manual);
      }
      expect(vm.sesionesPasadas.single.asistieron, 0);
    });

    test('si no se puede guardar, lo dice y no cambia nada', () async {
      servicio.sesionesPorCurso['c1'] = [llamado('s1', 20, 2)];

      vm.vigilar('c1');
      await pumpEventQueue();
      servicio.fallo = const CursoException('permiso denegado');
      final ana = vm.detalleDeFranja(franja20).last.inscrito;
      final error = await vm.corregirAsistencia(
        franja20,
        ana,
        presente: true,
        docenteUid: 'uid-docente',
      );

      expect(error, 'permiso denegado');
      expect(vm.detalleDeFranja(franja20).every((f) => !f.presente), isTrue);
    });
  });
}
