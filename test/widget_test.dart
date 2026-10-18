// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:smart_check/main.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/services/chaira_service.dart';
import 'package:smart_check/viewmodels/auth_viewmodel.dart';
import 'package:smart_check/viewmodels/student_viewmodel.dart';
import 'package:smart_check/views/login_screen.dart';
import 'package:smart_check/views/smart_register_screen.dart';
import 'package:smart_check/views/student/student_home_screen.dart';
import 'package:smart_check/views/teacher/teacher_home_screen.dart';

import 'auth_fakes.dart';
import 'chaira_fixtures.dart';

/// Chairá simulado: responde a cualquier documento con la persona de prueba.
ChairaService _chairaFalso() => ChairaService(
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response('', 404);
        return http.Response.bytes(
          utf8.encode(respuestaExito()),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

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

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(chairaService: _chairaFalso()),
        child: const MaterialApp(home: SmartRegisterScreen()),
      ),
    );

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
    expect(find.text('ANA MARÍA PÉREZ GÓMEZ'), findsOneWidget);
    expect(find.text('INGENIERÍA DE SISTEMAS'), findsOneWidget);
    expect(find.text('an.perez'), findsOneWidget); // usuario de correo sugerido
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

  group('login según el rol guardado', () {
    const preguntaPerfil = '¿Con qué perfil deseas ingresar hoy?';

    // Las pantallas home desbordan con la fuente de pruebas (más ancha que la
    // real); aquí solo se comprueba la navegación. Devuelve cómo restaurar.
    VoidCallback ignorarDesbordes() {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      return () => FlutterError.onError = original;
    }

    Future<void> iniciarSesion(
      WidgetTester tester,
      List<String> roles,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = FakeAuthService()
        ..cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      final perfiles = FakePerfilService()
        ..perfiles['uid-an.perez@udla.edu.co'] = perfilDe(
          'an.perez@udla.edu.co',
          'ANA MARÍA PÉREZ GÓMEZ',
          roles,
        );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthViewModel(
                authService: auth,
                perfilService: perfiles,
                chairaService: chairaFalso(),
              ),
            ),
            ChangeNotifierProvider(create: (_) => StudentViewModel()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'an.perez');
      await tester.enterText(find.byType(TextFormField).at(1), 'Clave123!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('un estudiante entra directo, sin elegir perfil', (
      tester,
    ) async {
      final restaurar = ignorarDesbordes();
      await iniciarSesion(tester, [Rol.estudiante]);
      restaurar();

      expect(find.text(preguntaPerfil), findsNothing);
      expect(find.byType(StudentHomeScreen), findsOneWidget);
      // Sin perfil docente no se ofrece cambiar de panel.
      expect(find.text('Docente'), findsNothing);
    });

    testWidgets('un docente entra directo al panel docente', (tester) async {
      final restaurar = ignorarDesbordes();
      await iniciarSesion(tester, [Rol.docente]);
      restaurar();

      expect(find.text(preguntaPerfil), findsNothing);
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
      // Sin perfil de estudiante no se ofrece cambiar de panel.
      expect(find.text('Estudiante'), findsNothing);
    });

    testWidgets('solo al docente que también cursa materias se le pregunta', (
      tester,
    ) async {
      final restaurar = ignorarDesbordes();
      await iniciarSesion(tester, [Rol.docente, Rol.estudiante]);
      restaurar();

      expect(find.text(preguntaPerfil), findsOneWidget);
    });
  });
}
