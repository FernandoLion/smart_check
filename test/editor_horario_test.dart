import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/viewmodels/teacher_viewmodel.dart';
import 'package:smart_check/views/teacher/create_course_screen.dart';

import 'curso_fakes.dart';

/// La hoja del horario semanal: el reloj es de AM y PM y, si la hora de fin
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

  /// Escribe [hora] ("1:30") y elige [periodo] ("AM" o "PM") en el reloj
  /// que abre [boton], en el modo de teclado.
  Future<void> elegir(
    WidgetTester tester,
    String boton,
    String hora,
    String periodo,
  ) async {
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final reloj = find.byType(Dialog);
    final partes = hora.split(':');
    final campos = find.descendant(of: reloj, matching: find.byType(TextField));
    await tester.enterText(campos.at(0), partes[0]);
    await tester.enterText(campos.at(1), partes[1]);
    await tester.tap(find.descendant(of: reloj, matching: find.text(periodo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
  }

  testWidgets('el reloj es de AM y PM, aunque el celular use 24 horas',
      (tester) async {
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    await abrirHoja(tester);

    await tester.tap(find.text('Inicio 8:00 AM'));
    await tester.pumpAndSettle();

    final reloj = find.byType(Dialog);
    expect(find.text('Hora de inicio'), findsOneWidget);
    expect(
      find.descendant(of: reloj, matching: find.text('Cancelar')),
      findsOneWidget,
    );
    expect(find.descendant(of: reloj, matching: find.text('AM')), findsOneWidget);
    expect(find.descendant(of: reloj, matching: find.text('PM')), findsOneWidget);
  });

  testWidgets('fin antes del inicio: el aviso sale dentro de la hoja',
      (tester) async {
    await abrirHoja(tester);

    await elegir(tester, 'Inicio 8:00 AM', '1:30', 'PM');
    expect(find.text('Inicio 1:30 PM'), findsOneWidget);
    // Se marca en cuanto pasa, sin esperar al botón.
    expect(
      find.text('La hora de fin debe ser después del inicio.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Agregar bloque'));
    await tester.pumpAndSettle();

    // No se agregó, y el aviso sigue a la vista dentro de la hoja.
    expect(find.textContaining('1:30 PM - 10:00 AM'), findsNothing);
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

    await elegir(tester, 'Fin 10:00 AM', '3:15', 'PM');
    await tester.tap(find.text('Agregar bloque'));
    await tester.pumpAndSettle();

    // En la hoja y en el resumen del curso, con AM y PM; guardado como
    // siempre, en 24 horas.
    expect(find.textContaining('8:00 AM - 3:15 PM'), findsOneWidget);
    expect(
      find.text('La hora de fin debe ser después del inicio.'),
      findsNothing,
    );
  });
}
