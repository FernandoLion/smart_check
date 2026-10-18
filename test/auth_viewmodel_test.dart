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
    test('guarda el perfil verificado con rol de estudiante', () async {
      final vm = crear();
      await vm.verificarEnChaira('1117000000');

      expect(await vm.register('an.perez', 'Clave123!'), isTrue);

      final guardado = perfiles.perfiles['uid-an.perez@udla.edu.co']!;
      expect(guardado.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
      expect(guardado.email, 'an.perez@udla.edu.co');
      expect(guardado.roles, [Rol.estudiante]);
      expect(vm.usuarioActual?.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
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

    test('avisa si la cuenta se creó pero el perfil no se guardó', () async {
      final vm = crear();
      await vm.verificarEnChaira('1117000000');
      perfiles.fallo = const PerfilException('permiso denegado');

      expect(await vm.register('an.perez', 'Clave123!'), isFalse);
      expect(vm.errorMessage, contains('Inicia sesión para completarlo'));
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
    });

    test('muestra al usuario logueado y no la última consulta a Chairá',
        () async {
      auth.cuentas['ca.munoz@udla.edu.co'] = 'Clave123!';
      perfiles.perfiles['uid-ca.munoz@udla.edu.co'] = perfilDe(
        'ca.munoz@udla.edu.co',
        'CARLOS ANDRÉS MUÑOZ RIVERA',
        [Rol.estudiante],
      );
      final vm = crear(tipoChaira: 'DOCENTE');

      // Se consulta a otra persona (una docente) sin registrarla...
      await vm.verificarEnChaira('1117000000');
      // ...y luego se inicia sesión con otra cuenta.
      await vm.signIn('ca.munoz', 'Clave123!');

      expect(vm.usuarioActual!.nombre, 'CARLOS ANDRÉS MUÑOZ RIVERA');
      expect(vm.verificacionResult, isNull);
    });

    test('rechaza credenciales incorrectas', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      final vm = crear();

      expect(await vm.signIn('an.perez', 'otra'), isFalse);
      expect(vm.perfil, isNull);
    });

    test('cierra la sesión si no puede leer el perfil', () async {
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      perfiles.fallo = const PerfilException('sin conexión');
      final vm = crear();

      expect(await vm.signIn('an.perez', 'Clave123!'), isFalse);
      expect(vm.errorMessage, 'sin conexión');
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
      expect(vm.usuarioActual, isNull);
    });
  });

  group('vincular cuentas sin perfil', () {
    test('vincula si el documento corresponde al usuario del correo', () async {
      // Chairá simulado devuelve a ANA MARÍA PÉREZ GÓMEZ -> "an.perez".
      auth.cuentas['an.perez@udla.edu.co'] = 'Clave123!';
      final vm = crear();
      await vm.signIn('an.perez', 'Clave123!');
      expect(vm.perfil, isNull);

      expect(await vm.vincularDocumento('1117000000'), isTrue);
      expect(vm.perfil!.roles, [Rol.estudiante]);
      expect(perfiles.perfiles['uid-an.perez@udla.edu.co'], isNotNull);
    });

    test('rechaza el documento de otra persona', () async {
      auth.cuentas['ca.munoz@udla.edu.co'] = 'Clave123!';
      final vm = crear(tipoChaira: 'DOCENTE');
      await vm.signIn('ca.munoz', 'Clave123!');

      expect(await vm.vincularDocumento('1117000000'), isFalse);
      expect(vm.errorMessage, contains('no corresponde'));
      expect(perfiles.perfiles, isEmpty);
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

    test('el registro solo crea cuentas @udla.edu.co', () async {
      final vm = crear();
      await vm.verificarEnChaira('1117000000');

      expect(await vm.register('an.perez@gmail.com', 'Clave123!'), isFalse);
      expect(auth.cuentas, isEmpty);
      expect(await vm.register('an.perez@udla.edu.co', 'Clave123!'), isTrue);
      expect(auth.cuentas.keys, ['an.perez@udla.edu.co']);
    });
  });
}
