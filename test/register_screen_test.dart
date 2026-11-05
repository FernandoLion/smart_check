import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/viewmodels/auth_viewmodel.dart';
import 'package:smart_check/views/login_screen.dart';
import 'package:smart_check/views/smart_register_screen.dart';

import 'auth_fakes.dart';

void main() {
  late FakeAuthService auth;
  late FakePerfilService perfiles;

  setUp(() {
    auth = FakeAuthService();
    perfiles = FakePerfilService();
  });

  /// Monta [pantalla] con los servicios falsos y Chairá simulado.
  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla, {
    String tipoChaira = 'ESTUDIANTE',
  }) async {
    // Un teléfono angosto (360 x 640) para comprobar que todo cabe.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(
          authService: auth,
          perfilService: perfiles,
          chairaService: chairaFalso(tipo: tipoChaira),
        ),
        child: MaterialApp(home: pantalla),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> verificar(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '1117000000');
    await tester.tap(find.text('Verificar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('desde el login se llega al registro', (tester) async {
    await abrir(tester, const LoginScreen());

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.byType(SmartRegisterScreen), findsOneWidget);
    expect(find.text('PASO 1: VALIDACIÓN DE IDENTIDAD'), findsOneWidget);
  });

  testWidgets('verificar muestra la tarjeta de Chairá y propone el usuario', (
    tester,
  ) async {
    await abrir(tester, const SmartRegisterScreen());

    await verificar(tester);

    expect(find.text('VERIFICADO EN SISTEMA'), findsOneWidget);
    expect(find.text('ANA MARÍA PÉREZ GÓMEZ'), findsOneWidget);
    expect(find.text('INGENIERÍA DE SISTEMAS'), findsOneWidget);
    expect(find.text('an.perez'), findsOneWidget);
    // Una estudiante no ve el interruptor de docentes.
    expect(find.text('También curso materias'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a un docente le ofrece "También curso materias"', (
    tester,
  ) async {
    await abrir(tester, const SmartRegisterScreen(), tipoChaira: 'DOCENTE');

    await verificar(tester);

    expect(find.text('También curso materias'), findsOneWidget);
  });

  testWidgets('no deja crear la cuenta sin verificar', (tester) async {
    await abrir(tester, const SmartRegisterScreen());

    await tester.ensureVisible(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pump();

    expect(
      find.text('Primero debes verificar tu documento en el Paso 1.'),
      findsOneWidget,
    );
    expect(auth.cuentas, isEmpty);
  });

  testWidgets('crear la cuenta guarda el perfil y entra a la app', (
    tester,
  ) async {
    await abrir(tester, const SmartRegisterScreen());
    await verificar(tester);

    final clave = find.byType(TextField).last;
    await tester.ensureVisible(clave);
    await tester.pumpAndSettle();
    await tester.enterText(clave, 'Clave123!');
    await tester.ensureVisible(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(auth.cuentas['an.perez@udla.edu.co'], 'Clave123!');
    expect(perfiles.perfiles['uid-an.perez@udla.edu.co']!.roles, [
      Rol.estudiante,
    ]);
    // Vuelve al login, que encuentra la sesión de la cuenta nueva y entra.
    expect(find.text('Bienvenido, estudiante'), findsOneWidget);
  });
}
