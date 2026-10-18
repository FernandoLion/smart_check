import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/services/curso_service.dart';
import 'package:smart_check/viewmodels/teacher_viewmodel.dart';

import 'curso_fakes.dart';

Curso cursoDe(String docenteUid, String nombre) => Curso(
      codigo: 'SIS-402',
      nombre: nombre,
      grupo: '302-B',
      aula: 'Aula 204',
      periodo: '2026-2',
      docenteUid: docenteUid,
      docenteNombre: 'ANA MARÍA PÉREZ GÓMEZ',
      horarios: const [
        Horario(dia: DateTime.tuesday, inicio: '08:00', fin: '10:00'),
      ],
    );

void main() {
  late FakeCursoService servicio;
  late TeacherViewModel vm;

  setUp(() {
    servicio = FakeCursoService();
    vm = TeacherViewModel(servicio: servicio);
  });

  tearDown(() => vm.dispose());

  test('muestra solo los cursos del docente, ordenados por nombre', () async {
    servicio.cursos['a'] = cursoDe('uid-docente', 'Redes');
    servicio.cursos['b'] = cursoDe('uid-otro', 'Bases de Datos');
    servicio.cursos['c'] = cursoDe('uid-docente', 'Arquitectura');

    vm.vigilarCursos('uid-docente');
    expect(vm.cargando, isTrue);
    await pumpEventQueue();

    expect(vm.cargando, isFalse);
    expect(vm.cursos.map((c) => c.nombre), ['Arquitectura', 'Redes']);
  });

  test('crea el curso, inscribe y la lista se actualiza sola', () async {
    vm.vigilarCursos('uid-docente');
    await pumpEventQueue();
    expect(vm.cursos, isEmpty);

    final id = await vm.crearCurso(cursoDe('uid-docente', 'Redes'), const [
      Inscrito(cedula: '1117000000', nombre: 'ANA'),
      Inscrito(email: 'ca.munoz@udla.edu.co', nombre: 'CARLOS'),
    ]);
    await pumpEventQueue();

    expect(id, isNotNull);
    expect(vm.guardando, isFalse);
    expect(vm.cursos.single.totalInscritos, 2);
    expect(
      vm.cursos.single.clavesInscritos,
      containsAll(['1117000000', 'ca.munoz@udla.edu.co']),
    );
  });

  test('informa el error si no se puede crear', () async {
    servicio.fallo = const CursoException('permiso denegado');

    final id = await vm.crearCurso(cursoDe('uid-docente', 'Redes'), const []);

    expect(id, isNull);
    expect(vm.error, 'permiso denegado');
    expect(vm.guardando, isFalse);
  });

  test('cambiar de docente cambia la lista', () async {
    servicio.cursos['a'] = cursoDe('uid-1', 'Redes');
    servicio.cursos['b'] = cursoDe('uid-2', 'Arquitectura');

    vm.vigilarCursos('uid-1');
    await pumpEventQueue();
    expect(vm.cursos.single.nombre, 'Redes');

    vm.vigilarCursos('uid-2');
    await pumpEventQueue();
    expect(vm.cursos.single.nombre, 'Arquitectura');
  });
}
