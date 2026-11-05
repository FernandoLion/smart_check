import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/viewmodels/auth_viewmodel.dart';
import 'package:smart_check/views/home_screen.dart';
import 'package:smart_check/views/login_screen.dart';

import 'auth_fakes.dart';

void main() {
  const preguntaPerfil = '¿Con qué perfil deseas ingresar hoy?';

  late FakeAuthService auth;
  late FakePerfilService perfiles;

  setUp(() {
    auth = FakeAuthService()..cuentas['an.perez@udla.edu.co'] = 'Clave123!';
    perfiles = FakePerfilService();
  });

  /// Abre el login con los servicios falsos (sin Firebase real).
  Future<void> abrirLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            AuthViewModel(authService: auth, perfilService: perfiles),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    // Primero mira si hay una sesión guardada; sin ella, pide el ingreso.
    await tester.pump();
    await tester.pump();
  }

  Future<void> iniciarSesion(WidgetTester tester, String clave) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'an.perez');
    await tester.enterText(find.byType(TextFormField).at(1), clave);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  void conRoles(List<String> roles) {
    perfiles.perfiles['uid-an.perez@udla.edu.co'] = perfilDe(
      'an.perez@udla.edu.co',
      'ANA MARÍA PÉREZ GÓMEZ',
      roles,
    );
  }

  testWidgets('muestra el formulario con el dominio fijo', (tester) async {
    await abrirLogin(tester);

    expect(find.text('SmartCheck'), findsOneWidget);
    expect(find.text('@udla.edu.co'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('pide los datos si los campos están vacíos', (tester) async {
    await abrirLogin(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
    await tester.pump();

    expect(find.text('Por favor, ingresa tus datos de acceso.'), findsOneWidget);
  });

  testWidgets('con la contraseña equivocada se queda en el login', (
    tester,
  ) async {
    conRoles([Rol.estudiante]);
    await abrirLogin(tester);

    await iniciarSesion(tester, 'otra');

    expect(find.text('Credenciales incorrectas.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('un estudiante entra directo, sin elegir perfil', (
    tester,
  ) async {
    conRoles([Rol.estudiante]);
    await abrirLogin(tester);

    await iniciarSesion(tester, 'Clave123!');

    expect(find.text(preguntaPerfil), findsNothing);
    expect(find.text('Bienvenido, estudiante'), findsOneWidget);
  });

  testWidgets('un docente entra directo como docente', (tester) async {
    conRoles([Rol.docente]);
    await abrirLogin(tester);

    await iniciarSesion(tester, 'Clave123!');

    expect(find.text(preguntaPerfil), findsNothing);
    expect(find.text('Bienvenido, docente'), findsOneWidget);
  });

  testWidgets('al docente que también estudia se le pregunta el perfil', (
    tester,
  ) async {
    conRoles([Rol.docente, Rol.estudiante]);
    await abrirLogin(tester);

    await iniciarSesion(tester, 'Clave123!');
    expect(find.text(preguntaPerfil), findsOneWidget);

    await tester.tap(find.text('Modo Estudiante (Asistencia)'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido, estudiante'), findsOneWidget);
  });

  testWidgets('con la sesión guardada entra sin pedir la contraseña', (
    tester,
  ) async {
    conRoles([Rol.estudiante]);
    // Como si la app se hubiera cerrado después de entrar.
    await auth.signInWithEmailPassword('an.perez@udla.edu.co', 'Clave123!');

    await abrirLogin(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('cerrar sesión vuelve al login', (tester) async {
    conRoles([Rol.estudiante]);
    await abrirLogin(tester);
    await iniciarSesion(tester, 'Clave123!');

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.currentUser, isNull);
  });
}
