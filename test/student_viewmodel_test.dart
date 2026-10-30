import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/curso_service.dart';
import 'package:smart_check/viewmodels/student_viewmodel.dart';

import 'curso_fakes.dart';

Curso cursoCon(String nombre, List<String> claves, {List<Horario> horarios = const []}) =>
    Curso(
      codigo: 'SIS-402',
      nombre: nombre,
      grupo: '302-B',
      aula: 'Aula 204',
      periodo: '2026-2',
      docenteUid: 'uid-docente',
      docenteNombre: 'ANA MARÍA PÉREZ GÓMEZ',
      horarios: horarios,
      clavesInscritos: claves,
    );

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

void main() {
  late FakeCursoService servicio;
  late StudentViewModel vm;

  setUp(() {
    servicio = FakeCursoService();
    vm = StudentViewModel(servicio: servicio);
  });

  tearDown(() => vm.dispose());

  test('muestra solo las materias donde está inscrito, por nombre', () async {
    servicio.cursos['a'] = cursoCon('Redes', ['1117000000']);
    servicio.cursos['b'] = cursoCon('Bases de Datos', ['1117000999']);
    servicio.cursos['c'] = cursoCon('Arquitectura', ['an.perez@udla.edu.co']);

    vm.vigilarCursos(cedula: '1117000000', email: 'An.Perez@udla.edu.co');
    expect(vm.cargando, isTrue);
    await pumpEventQueue();

    expect(vm.cargando, isFalse);
    expect(vm.subjects.map((s) => s.name), ['Arquitectura', 'Redes']);
  });

  test('sin cédula ni correo no consulta nada', () async {
    servicio.cursos['a'] = cursoCon('Redes', ['1117000000']);

    vm.vigilarCursos();
    await pumpEventQueue();

    expect(vm.cargando, isFalse);
    expect(vm.subjects, isEmpty);
  });

  test('calcula la asistencia de cada materia y la global', () async {
    servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);
    servicio.cursos['b'] = cursoCon('Redes', ['1117000000']);
    servicio.resumenes['a'] = const AsistenciaResumen(sesiones: 10, asistidas: 9);
    servicio.resumenes['b'] = const AsistenciaResumen(sesiones: 10, asistidas: 7);

    vm.vigilarCursos(cedula: '1117000000');
    await pumpEventQueue();

    expect(vm.subjects.map((s) => s.attendancePercent), [90, 70]);
    expect(vm.subjects.map((s) => s.status),
        [NivelAsistencia.alDia, NivelAsistencia.riesgo]);
    expect(vm.globalAttendance, 80);
    expect(vm.globalAttendanceStatus, 'Atención');
    expect(vm.materiasEnRiesgo, 1);
  });

  test('sin sesiones terminadas no inventa un porcentaje', () async {
    servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);

    vm.vigilarCursos(cedula: '1117000000');
    await pumpEventQueue();

    expect(vm.subjects.single.attendancePercent, isNull);
    expect(vm.subjects.single.statusLabel, 'Sin registro');
    expect(vm.globalAttendance, isNull);
    expect(vm.globalAttendanceStatus, 'Sin clases aún');
  });

  group('el botón de registrar asistencia', () {
    test('sin llamado abierto no se puede registrar', () async {
      servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);

      vm.vigilarCursos(cedula: '1117000000');
      await pumpEventQueue();

      expect(vm.puedeRegistrar, isFalse);
      expect(vm.llamadoVigente, isNull);
    });

    test('con un llamado abierto se puede registrar en esa materia', () async {
      servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);
      servicio.cursos['b'] = cursoCon('Redes', ['1117000000']);
      servicio.sesionesPorCurso['b'] = [llamadoAbierto()];

      vm.vigilarCursos(cedula: '1117000000');
      await pumpEventQueue();

      expect(vm.puedeRegistrar, isTrue);
      expect(vm.llamadoVigente!.$1.nombre, 'Redes');
      expect(vm.llamadoVigente!.$2.id, 'llamado-1');
    });

    test('un llamado marcado como abierto pero vencido no cuenta', () async {
      final ahora = DateTime.now();
      servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);
      // Quedó abierto porque al docente se le murió la app.
      servicio.sesionesPorCurso['a'] = [
        Sesion(
          id: 'colgado',
          inicio: ahora.subtract(const Duration(minutes: 20)),
          fin: ahora.subtract(const Duration(minutes: 10)),
        ),
      ];

      vm.vigilarCursos(cedula: '1117000000');
      await pumpEventQueue();

      expect(vm.puedeRegistrar, isFalse);
    });

    test('al cerrarse el llamado el botón se apaga solo', () async {
      servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);
      servicio.sesionesPorCurso['a'] = [llamadoAbierto()];

      vm.vigilarCursos(cedula: '1117000000');
      await pumpEventQueue();
      expect(vm.puedeRegistrar, isTrue);

      await servicio.cerrarSesion('a', 'llamado-1');
      await pumpEventQueue();

      expect(vm.puedeRegistrar, isFalse);
    });
  });

  test('informa el error si no se puede leer la asistencia', () async {
    servicio.cursos['a'] = cursoCon('Arquitectura', ['1117000000']);
    servicio.fallo = const CursoException('permiso denegado');

    vm.vigilarCursos(cedula: '1117000000');
    await pumpEventQueue();

    expect(vm.error, 'permiso denegado');
    // Las materias se siguen viendo aunque falle el conteo de asistencia.
    expect(vm.subjects.single.name, 'Arquitectura');
  });
}
