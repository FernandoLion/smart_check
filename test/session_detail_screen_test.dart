import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';
import 'package:smart_check/views/teacher/session_detail_screen.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

void main() {
  late FakeCursoService servicio;
  late CourseDetailViewModel vm;
  final curso = cursoEnClase();
  final llamado = Sesion(
    id: 's1',
    inicio: DateTime(2026, 10, 20, 8, 2),
    fin: DateTime(2026, 10, 20, 8, 12),
    abierta: false,
    bloqueInicio: DateTime(2026, 10, 20, 8),
  );

  setUp(() {
    servicio = FakeCursoService();
    servicio.inscritosPorCurso[curso.id] = {
      'ana': const Inscrito(cedula: 'ana', nombre: 'ANA PÉREZ'),
      'carlos': const Inscrito(cedula: 'carlos', nombre: 'CARLOS MUÑOZ'),
    };
    servicio.sesionesPorCurso[curso.id] = [llamado];
    servicio.asistenciasPorSesion['s1'] = [
      Asistencia(
        claveInscrito: 'carlos',
        estado: EstadoAsistencia.presente,
        metodo: MetodoAsistencia.ble,
        hora: DateTime(2026, 10, 20, 8, 5),
        registradoPor: 'uid-docente',
      ),
    ];
  });

  // Dentro de la prueba, y no en setUp: los streams del servicio tienen que
  // correr en el reloj falso de testWidgets.
  Future<void> abrir(WidgetTester tester) async {
    vm = CourseDetailViewModel(
      servicio: servicio,
      reloj: () => DateTime(2026, 10, 26, 9),
    )..vigilar(curso.id);
    addTearDown(vm.dispose);
    // Alta, para que la lista (perezosa) construya todas las filas.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailScreen(
          curso: curso,
          vm: vm,
          franja: llamado.franja,
          fechaTitulo: 'Martes 20 de octubre de 2026',
          horario: 'Llamado 08:02 - 08:12',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra a los inscritos de verdad, no una lista de ejemplo',
      (tester) async {
    await abrir(tester);

    expect(find.text('CARLOS MUÑOZ'), findsOneWidget);
    expect(find.text('ANA PÉREZ'), findsOneWidget);
    expect(find.text('Mateo Gómez Silva'), findsNothing);
    // A quien vino también se le puede corregir, y se ve.
    expect(find.text('08:05 · Marcar ausente'), findsOneWidget);
    expect(find.text('Presentes (1)'), findsOneWidget);
    expect(find.text('Ausentes (1)'), findsOneWidget);
  });

  testWidgets('marcar presente a mano lo guarda y lo muestra',
      (tester) async {
    await abrir(tester);

    await tester.ensureVisible(find.text('Marcar presente'));
    await tester.tap(find.text('Marcar presente'));
    await tester.pumpAndSettle();

    final guardada = servicio.asistenciasPorSesion['s1']!
        .firstWhere((a) => a.claveInscrito == 'ana');
    expect(guardada.metodo, MetodoAsistencia.manual);
    expect(guardada.estado, EstadoAsistencia.presente);
    expect(find.text('Presentes (2)'), findsOneWidget);
    expect(find.text('Marcar presente'), findsNothing);
  });

  testWidgets('a quien no vino se le puede justificar la falta',
      (tester) async {
    await abrir(tester);

    await tester.ensureVisible(find.text('Justificar'));
    await tester.tap(find.text('Justificar'));
    await tester.pumpAndSettle();

    final guardada = servicio.asistenciasPorSesion['s1']!
        .firstWhere((a) => a.claveInscrito == 'ana');
    expect(guardada.estado, EstadoAsistencia.justificada);
    expect(guardada.metodo, MetodoAsistencia.manual);
    expect(find.text('Justificada'), findsOneWidget);
    expect(find.text('Quitar justificación'), findsOneWidget);
  });
}
