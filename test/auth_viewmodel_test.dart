import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/services/perfil_service.dart';
import 'package:smart_check/viewmodels/auth_viewmodel.dart';

import 'auth_fakes.dart';

void main() {
  late FakeAuthService auth;
  late FakePerfilService perfiles;

  setUp(() {
    auth = FakeAuthService();
    perfiles = FakePerfilService();
  });

  AuthViewModel crear({String tipoChaira = 'ESTUDIANTE'}) => AuthViewModel(
    authService: auth,
    perfilService: perfiles,
    chairaService: chairaFalso(tipo: tipoChaira),
  );

  group('registro', () {
    test('verificar en Chairá trae los datos de la persona', () async {
      final vm = crear();

      expect(await vm.verificarEnChaira('1117000000'), isTrue);
      expect(vm.verificacionResult!.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
      expect(vm.verificacionResult!.username, 'an.perez');
      expect(vm.isVerifyingChaira, isFalse);
    });

    test('guarda el perfil verificado con rol de estudiante', () async {
      final vm = crear();
      await vm.verificarEnChaira('1117000000');

      expect(await vm.register('an.perez', 'Clave123!'), isTrue);

      final guardado = perfiles.perfiles['uid-an.perez@udla.edu.co']!;
      expect(guardado.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
      expect(guardado.email, 'an.perez@udla.edu.co');
      expect(guardado.roles, [Rol.estudiante]);
      expect(vm.perfil, isNotNull);
    });

    test('un docente solo es estudiante si activa "También curso materias"',
        () async {
      final vm = crear(tipoChaira: 'DOCENTE');
      await vm.verificarEnChaira('1117000000');
      await vm.register('solo.docente', 'Clave123!');
      await vm.verificarEnChaira('1117000000');
      await vm.register('dual', 'Clave123!', tambienEstudiante: true);

      expect(perfiles.perfiles['uid-solo.docente@udla.edu.co']!.roles,
          [Rol.docente]);
      expect(perfiles.perfiles['uid-dual@udla.edu.co']!.esDual, isTrue);
    });

    test('no registra sin verificar el documento', () async {
      final vm = crear();

      expect(await vm.register('an.perez', 'Clave123!'), isFalse);
      expect(auth.cuentas, isEmpty);
    });

    test('solo crea cuentas @udla.edu.co', () async {
      final vm = crear();
      await vm.verificarEnChaira('1117000000');

      expect(await vm.register('an.perez@gmail.com', 'Clave123!'), isFalse);
      expect(auth.cuentas, isEmpty);
      expect(await vm.register('an.perez@udla.edu.co', 'Clave123!'), isTrue);
      expect(auth.cuentas.keys, ['an.perez@udla.edu.co']);
    });

    test('avisa si la cuenta se creó pero el perfil no se guardó', () async {
      final vm = crear();
      await vm.verificarEnChaira('1117000000');
      perfiles.fallo = const PerfilException('permiso denegado');

      expect(await vm.register('an.perez', 'Clave123!'), isFalse);
      expect(vm.errorMessage, contains('no se pudo guardar tu perfil'));
    });

    test('el perfil se guarda con los mismos campos que lee el login', () {
      final perfil = perfilDe('an.perez@udla.edu.co', 'ANA', [Rol.estudiante]);
      final releido = UsuarioPerfil.fromMap(perfil.uid, perfil.toMap());

      expect(releido.nombre, 'ANA');
      expect(releido.cedula, '1117000001');
      expect(releido.roles, [Rol.estudiante]);
    });
  });

  group('inicio de sesión', () {
    test('carga el perfil y los roles guardados', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      perfiles.perfiles['uid-an.perez@udla.edu.co'] = perfilDe(
        'an.perez@udla.edu.co',
        'ANA MARÍA PÉREZ GÓMEZ',
        [Rol.estudiante],
      );
      final vm = crear();

      expect(await vm.signIn('AN.Perez', 'Clave123!'), isTrue);
      expect(vm.perfil!.esEstudiante, isTrue);
      expect(vm.perfil!.esDocente, isFalse);
      expect(vm.isLoading, isFalse);
    });

    test('rechaza credenciales incorrectas', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      final vm = crear();

      expect(await vm.signIn('an.perez', 'otra'), isFalse);
      expect(vm.perfil, isNull);
      expect(vm.errorMessage, isNotNull);
    });

    test('cierra la sesión si no puede leer el perfil', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      perfiles.fallo = const PerfilException('sin conexión');
      final vm = crear();

      expect(await vm.signIn('an.perez', 'Clave123!'), isFalse);
      expect(vm.errorMessage, 'sin conexión');
      expect(auth.currentUser, isNull);
    });

    test('cierra la sesión si la cuenta no tiene perfil', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      final vm = crear();

      expect(await vm.signIn('an.perez', 'Clave123!'), isFalse);
      expect(vm.errorMessage, 'Tu cuenta no tiene un perfil registrado.');
      expect(auth.currentUser, isNull);
    });

    test('cerrar sesión borra el perfil', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      perfiles.perfiles['uid-an.perez@udla.edu.co'] = perfilDe(
        'an.perez@udla.edu.co',
        'ANA MARÍA PÉREZ GÓMEZ',
        [Rol.estudiante],
      );
      final vm = crear();
      await vm.signIn('an.perez', 'Clave123!');

      await vm.signOut();

      expect(vm.perfil, isNull);
      expect(auth.currentUser, isNull);
    });

    test('restaura la sesión guardada sin pedir la contraseña', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      await auth.signInWithEmailPassword('an.perez@udla.edu.co', 'Clave123!');
      perfiles.perfiles['uid-an.perez@udla.edu.co'] = perfilDe(
        'an.perez@udla.edu.co',
        'ANA MARÍA PÉREZ GÓMEZ',
        [Rol.docente],
      );
      final vm = crear();

      expect(await vm.restaurarSesion(), isTrue);
      expect(vm.perfil!.esDocente, isTrue);
    });
  });

  group('usuario institucional (@udla.edu.co fijo)', () {
    test('completa el usuario con el dominio', () {
      expect(AuthViewModel.correoInstitucional(' AN.Perez '),
          'an.perez@udla.edu.co');
      expect(AuthViewModel.correoInstitucional('an.perez@udla.edu.co'),
          'an.perez@udla.edu.co');
      expect(AuthViewModel.correoInstitucional('wi.patino-2'),
          'wi.patino-2@udla.edu.co');
    });

    test('rechaza otros dominios y usuarios mal escritos', () {
      expect(AuthViewModel.correoInstitucional('a@gmail.com'), isNull);
      expect(AuthViewModel.errorUsuario('a@gmail.com'),
          'Solo se permiten cuentas @udla.edu.co.');
      for (final malo in ['', 'an perez', 'an..perez', '.an', 'an.', 'an@']) {
        expect(AuthViewModel.correoInstitucional(malo), isNull, reason: malo);
      }
    });

    test('el login no consulta Firebase con un usuario inválido', () async {
      final vm = crear();

      expect(await vm.signIn('a@gmail.com', 'Clave123!'), isFalse);
      expect(vm.errorMessage, 'Solo se permiten cuentas @udla.edu.co.');
    });
  });

  group('perfil', () {
    test('lee nombre y roles del documento de Firestore', () {
      final perfil = UsuarioPerfil.fromMap('uid', {
        'email': 'an.perez@udla.edu.co',
        'nombre': 'ANA',
        'roles': ['docente', 'estudiante'],
      });

      expect(perfil.nombre, 'ANA');
      expect(perfil.esDual, isTrue);
    });

    test('un documento sin roles no rompe la app', () {
      final perfil = UsuarioPerfil.fromMap('uid', {});

      expect(perfil.roles, isEmpty);
      expect(perfil.esDocente, isFalse);
      expect(perfil.esEstudiante, isFalse);
    });
  });
}
