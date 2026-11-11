import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/viewmodels/teacher_viewmodel.dart';
import 'package:smart_check/views/teacher/create_course_screen.dart';

import 'curso_fakes.dart';

/// La hoja del horario semanal: el reloj es de 24 horas y, si la hora de fin
/// queda antes del inicio, lo dice dentro de la hoja (no detrás de ella).
void main() {
  Future<void> abrirHoja(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TeacherViewModel(servicio: FakeCursoService()),
        child: const MaterialApp(home: CreateCourseScreen()),
      ),
    );
    await tester.ensureVisible(find.text('Toca para agregar'));
    await tester.tap(find.text('Toca para agregar'));
    await tester.pumpAndSettle();
  }

  /// Escribe [hora] en el reloj que abre [boton], en el modo de teclado.
  Future<void> elegir(WidgetTester tester, String boton, String hora) async {
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final partes = hora.split(':');
    final campos = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(campos.at(0), partes[0]);
    await tester.enterText(campos.at(1), partes[1]);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
  }

  testWidgets('el reloj es de 24 horas y en español', (tester) async {
    await abrirHoja(tester);

    await tester.tap(find.text('Inicio 08:00'));
    await tester.pumpAndSettle();

    final reloj = find.byType(Dialog);
    expect(find.text('Hora de inicio'), findsOneWidget);
    expect(
      find.descendant(of: reloj, matching: find.text('Cancelar')),
      findsOneWidget,
    );
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
  });

  testWidgets('fin antes del inicio: el aviso sale dentro de la hoja',
      (tester) async {
    await abrirHoja(tester);

    await elegir(tester, 'Inicio 08:00', '13:30');
    expect(find.text('Inicio 13:30'), findsOneWidget);
    // Se marca en cuanto pasa, sin esperar al botón.
    expect(
      find.text('La hora de fin debe ser después del inicio.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Agregar bloque'));
    await tester.pumpAndSettle();

    // No se agregó, y el aviso sigue a la vista dentro de la hoja.
    expect(find.textContaining('13:30 - 10:00'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('La hora de fin debe ser después del inicio.'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('con la hora bien, el bloque se agrega', (tester) async {
    await abrirHoja(tester);

    await elegir(tester, 'Fin 10:00', '11:30');
    await tester.tap(find.text('Agregar bloque'));
    await tester.pumpAndSettle();

    expect(find.textContaining('08:00 - 11:30'), findsOneWidget);
    expect(
      find.text('La hora de fin debe ser después del inicio.'),
      findsNothing,
    );
  });
}
