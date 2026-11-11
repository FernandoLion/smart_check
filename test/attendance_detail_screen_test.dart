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

    // Primero el mes, con la leyenda del diseño de Stitch.
    expect(find.text('CALENDARIO DE ASISTENCIA'), findsOneWidget);
    expect(find.text('Vista Mes'), findsOneWidget);
    expect(find.text('Presente'), findsOneWidget);
    expect(find.text('Falla'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Lunes 19 de octubre'), findsNothing);

    // "Historial Completo" muestra cada clase dictada.
    await tester.tap(find.text('Historial Completo'));
    await tester.pumpAndSettle();
    expect(find.text('Lunes 19 de octubre'), findsOneWidget);
    expect(find.text('Radar BLE • 08:05'), findsOneWidget);
    expect(find.text('Martes 20 de octubre'), findsOneWidget);
    expect(find.text('Sin marca'), findsOneWidget);
    expect(find.text('Asistió'), findsOneWidget);
    expect(find.text('Faltó'), findsOneWidget);
    // Nada de la maqueta de antes.
    expect(find.textContaining('Aula 301'), findsNothing);
    expect(find.textContaining('Acuerdo 014'), findsNothing);
    expect(find.textContaining('Marzo 2025'), findsNothing);
  });

  testWidgets('el termómetro sale del resumen real', (tester) async {
    await abrir(tester);

    expect(find.text('50%'), findsOneWidget);
    // Las fallas se cuentan sobre el semestre, no sobre las 2 clases
    // dictadas: lleva 1 y le quedan las demás.
    final total = curso.clasesDelSemestre!;
    final permitidas = (total * 20 / 100).floor();
    expect(find.text('Te quedan ${permitidas - 1} fallas'), findsOneWidget);
    expect(find.text('2/$total'), findsOneWidget);
    expect(find.textContaining('de $total clases'), findsOneWidget);
    expect(find.text('Por debajo del mínimo'), findsNothing);
  });
}
