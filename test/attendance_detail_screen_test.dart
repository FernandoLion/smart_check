import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/models/student_subject_model.dart';
import 'package:smart_check/viewmodels/student_viewmodel.dart';
import 'package:smart_check/views/student/attendance_detail_screen.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

void main() {
  late FakeCursoService servicio;
  final curso = cursoEnClase();

  Sesion clase(String id, int dia) => Sesion(
        id: id,
        inicio: DateTime(2026, 10, dia, 8, 2),
        fin: DateTime(2026, 10, dia, 8, 12),
        abierta: false,
        bloqueInicio: DateTime(2026, 10, dia, 8),
      );

  setUp(() {
    servicio = FakeCursoService();
    servicio.sesionesPorCurso[curso.id] = [clase('s1', 19), clase('s2', 20)];
    servicio.asistenciasPorSesion['s1'] = [
      Asistencia(
        claveInscrito: '1117000000',
        estado: EstadoAsistencia.presente,
        metodo: MetodoAsistencia.ble,
        hora: DateTime(2026, 10, 19, 8, 5),
        registradoPor: 'uid-docente',
      ),
    ];
  });

  Future<void> abrir(WidgetTester tester) async {
    final estudiante = StudentViewModel(servicio: servicio)
      ..vigilarCursos(cedula: '1117000000');
    addTearDown(estudiante.dispose);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estudiante,
        child: MaterialApp(
          home: AttendanceDetailScreen(
            subject: StudentSubjectModel.desdeCurso(
              curso,
              asistencia: const AsistenciaResumen(sesiones: 2, asistidas: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra cada clase dictada con lo que pasó de verdad',
      (tester) async {
    await abrir(tester);

    expect(find.text('Lunes 19 de octubre'), findsOneWidget);
    expect(find.text('Radar BLE • 08:05'), findsOneWidget);
    expect(find.text('Martes 20 de octubre'), findsOneWidget);
    expect(find.text('Sin marca'), findsOneWidget);
    // Uno en la lista y otro en la leyenda del calendario.
    expect(find.text('Asistió'), findsNWidgets(2));
    expect(find.text('Faltó'), findsNWidgets(2));
    expect(find.text('CALENDARIO DE ASISTENCIA'), findsOneWidget);
    // Nada de la maqueta de antes.
    expect(find.textContaining('Aula 301'), findsNothing);
    expect(find.textContaining('Acuerdo 014'), findsNothing);
    expect(find.textContaining('Marzo 2025'), findsNothing);
  });

  testWidgets('el termómetro sale del resumen real', (tester) async {
    await abrir(tester);

    expect(find.text('50%'), findsOneWidget);
    // Con 2 clases el 80 % no deja ninguna falla, y ya lleva una.
    expect(find.text('Por debajo del mínimo'), findsOneWidget);
  });
}
