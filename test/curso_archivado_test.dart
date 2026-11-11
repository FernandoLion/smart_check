import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';
import 'package:smart_check/viewmodels/teacher_viewmodel.dart';
import 'package:smart_check/views/attendance/attendance_radar_screen.dart';
import 'package:smart_check/views/teacher/course_detail_screen.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

/// El detalle del curso: archivado es de solo lectura, y sin zona del aula
/// no se ofrece el radar.
void main() {
  late FakeCursoService cursos;

  setUp(() {
    cursos = FakeCursoService();
    cursos.inscritosPorCurso['c1'] = {
      '1117000000': const Inscrito(cedula: '1117000000', nombre: 'ANA PÉREZ'),
    };
  });

  Future<void> abrir(WidgetTester tester, Curso curso) async {
    // Ancho: la letra de las pruebas es más ancha que la del celular (el
    // tamaño real lo revisa responsive_test, con Roboto).
    tester.view.physicalSize = const Size(2000, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    cursos.cursos[curso.id] = curso;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TeacherViewModel(servicio: cursos),
        child: MaterialApp(
          home: CourseDetailScreen(
            curso: curso,
            vm: CourseDetailViewModel(servicio: cursos),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tocarIniciarRadar(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Iniciar Radar'));
    await tester.tap(find.text('Iniciar Radar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('archivado: lo dice, y el radar no se abre', (tester) async {
    await abrir(tester, cursoEnClase(archivado: true));

    expect(find.textContaining('Curso archivado: solo lectura'), findsOneWidget);
    await tocarIniciarRadar(tester);

    expect(find.byType(AttendanceRadarScreen), findsNothing);
    expect(find.textContaining('está archivado'), findsOneWidget);
  });

  testWidgets('archivado: en las opciones solo queda activar o eliminar',
      (tester) async {
    await abrir(tester, cursoEnClase(archivado: true));

    await tester.tap(find.byTooltip('Más opciones del curso'));
    await tester.pumpAndSettle();

    expect(find.text('Activar curso'), findsOneWidget);
    expect(find.text('Eliminar curso'), findsOneWidget);
    expect(find.text('Editar curso'), findsNothing);
    expect(find.text('Agregar estudiantes'), findsNothing);
  });

  testWidgets('sin zona del aula, el radar dice qué falta', (tester) async {
    await abrir(tester, cursoEnClase(geocerca: null));

    await tocarIniciarRadar(tester);

    expect(find.byType(AttendanceRadarScreen), findsNothing);
    expect(find.textContaining('no tiene zona del aula'), findsOneWidget);
  });

  Future<void> irAEstudiantes(WidgetTester tester) async {
    await tester.tap(find.text('Estudiantes'));
    await tester.pumpAndSettle();
  }

  testWidgets('deslizar a la izquierda quita al estudiante, tras confirmar',
      (tester) async {
    await abrir(tester, cursoEnClase());
    await irAEstudiantes(tester);

    await tester.drag(find.text('ANA PÉREZ'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar a ANA PÉREZ?'), findsOneWidget);

    // El "Quitar" del diálogo, no el que asoma detrás de la tarjeta.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Quitar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(cursos.inscritosPorCurso['c1'], isEmpty);
    expect(find.text('ANA PÉREZ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si cancela, la tarjeta vuelve y no se quita a nadie',
      (tester) async {
    await abrir(tester, cursoEnClase());
    await irAEstudiantes(tester);

    await tester.drag(find.text('ANA PÉREZ'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(cursos.inscritosPorCurso['c1'], hasLength(1));
    expect(find.text('ANA PÉREZ'), findsOneWidget);
  });

  testWidgets('archivado, deslizar no quita a nadie', (tester) async {
    await abrir(tester, cursoEnClase(archivado: true));
    await irAEstudiantes(tester);

    await tester.drag(find.text('ANA PÉREZ'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('¿Quitar a ANA PÉREZ?'), findsNothing);
    expect(cursos.inscritosPorCurso['c1'], hasLength(1));
  });
}
