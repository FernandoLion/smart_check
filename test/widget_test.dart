// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_check/main.dart';
import 'package:smart_check/screens/smart_register_screen.dart';

void main() {
  testWidgets('SmartCheck app renders login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmartCheckApp());
    await tester.pumpAndSettle();

    expect(find.text('SmartCheck'), findsOneWidget);
    expect(find.text('Acceso Universitario Inteligente'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
  });

  testWidgets('registration screen lays out and scrolls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SmartRegisterScreen()));

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('PASO 1: VALIDACIÓN DE IDENTIDAD'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.ensureVisible(find.text('Verificar'));
    await tester.tap(find.text('Verificar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('VERIFICADO EN SISTEMA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('REGISTRAR ROSTRO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening registration from login does not throw', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SmartCheckApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.text('Registro Inteligente Institucional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
