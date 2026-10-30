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

  group('vinculación del celular', () {
    const correo = 'an.perez@udla.edu.co';
    const uid = 'uid-$correo';
    final hoy = DateTime(2026, 3, 10, 9);

    /// Un viewmodel con la sesión ya iniciada y el reloj parado en [ahora].
    Future<AuthViewModel> conSesion({
      DateTime? ahora,
      String? esteCelular = 'android-1234567890',
    }) async {
      auth.cuentas[correo] = 'Clave123!';
      perfiles.perfiles[uid] = perfilDe(correo, 'ANA PÉREZ', [Rol.estudiante]);
      perfiles.horaDelServidor = ahora ?? hoy;
      final vm = AuthViewModel(
        authService: auth,
        perfilService: perfiles,
        chairaService: chairaFalso(),
        dispositivos: FakeDispositivoService(esteCelular),
        reloj: () => ahora ?? hoy,
      );
      await vm.signIn('an.perez', 'Clave123!');
      return vm;
    }

    test('sin celular vinculado se puede vincular', () async {
      final vm = await conSesion();

      expect(vm.dispositivoVinculado, isNull);
      expect(vm.puedeVincular, isTrue);
      expect(await vm.esEsteDispositivo(), isFalse);
    });

    test('vincular ata este celular y lo deja en el historial', () async {
      final vm = await conSesion();

      expect(await vm.vincularEsteDispositivo(), isTrue);

      expect(vm.dispositivoVinculado, 'android-1234567890');
      expect(await vm.esEsteDispositivo(), isTrue);
      // La fecha es la del servidor, no la del celular: es la que después
      // tiene que coincidir con cada presencia firmada.
      expect(vm.perfil?.dispositivoDesde, hoy);
      final historial = await vm.historialDeDispositivos();
      expect(historial.single.dispositivoId, 'android-1234567890');
      expect(historial.single.anterior, isNull);
    });

    test('antes de la semana no deja cambiar de celular', () async {
      final vm = await conSesion();
      await vm.vincularEsteDispositivo();

      final seisDias = AuthViewModel(
        authService: auth,
        perfilService: perfiles,
        chairaService: chairaFalso(),
        dispositivos: FakeDispositivoService('android-otro-celular'),
        reloj: () => hoy.add(const Duration(days: 6)),
      );
      await seisDias.signIn('an.perez', 'Clave123!');

      expect(seisDias.puedeVincular, isFalse);
      expect(await seisDias.vincularEsteDispositivo(), isFalse);
      expect(seisDias.errorMessage, contains('17/03'));
      // Y no tocó nada: sigue atado el primero.
      expect(seisDias.dispositivoVinculado, 'android-1234567890');
    });

    test('pasada la semana sí deja cambiar, y queda el anterior', () async {
      final vm = await conSesion();
      await vm.vincularEsteDispositivo();

      final despues = hoy.add(const Duration(days: 8));
      perfiles.horaDelServidor = despues;
      final otro = AuthViewModel(
        authService: auth,
        perfilService: perfiles,
        chairaService: chairaFalso(),
        dispositivos: FakeDispositivoService('android-otro-celular'),
        reloj: () => despues,
      );
      await otro.signIn('an.perez', 'Clave123!');

      expect(otro.puedeVincular, isTrue);
      expect(await otro.vincularEsteDispositivo(), isTrue);
      expect(otro.dispositivoVinculado, 'android-otro-celular');
      final historial = await otro.historialDeDispositivos();
      expect(historial.length, 2);
      expect(historial.first.anterior, 'android-1234567890');
    });

    test('sin identificador de la plataforma no se vincula', () async {
      final vm = await conSesion(esteCelular: null);

      expect(await vm.vincularEsteDispositivo(), isFalse);
      expect(vm.errorMessage, contains('no da un identificador'));
      expect(vm.dispositivoVinculado, isNull);
    });

    test('otro celular con la misma cuenta no es el vinculado', () async {
      final vm = await conSesion();
      await vm.vincularEsteDispositivo();

      final prestado = AuthViewModel(
        authService: auth,
        perfilService: perfiles,
        chairaService: chairaFalso(),
        dispositivos: FakeDispositivoService('android-del-amigo'),
        reloj: () => hoy,
      );
      await prestado.signIn('an.perez', 'Clave123!');

      expect(await prestado.esEsteDispositivo(), isFalse);
    });
  });

  group('perfil y dispositivo', () {
    final atado = DateTime(2026, 3, 10, 9);
    final perfil = perfilDe('an.perez@udla.edu.co', 'ANA', [Rol.estudiante])
        .conDispositivo('android-1234567890', atado);

    test('la espera entre celulares es de una semana', () {
      expect(perfil.puedeVincular(atado), isFalse);
      expect(perfil.puedeVincular(atado.add(const Duration(days: 6))), isFalse);
      expect(perfil.puedeVincular(atado.add(const Duration(days: 7))), isTrue);
      expect(perfil.proximoCambio(atado), atado.add(const Duration(days: 7)));
      expect(perfil.proximoCambio(atado.add(const Duration(days: 7))), isNull);
    });

    test('un perfil viejo sin celular puede vincular desde ya', () {
      final viejo = UsuarioPerfil.fromMap('uid', {
        'email': 'an.perez@udla.edu.co',
        'nombre': 'ANA',
        'roles': ['estudiante'],
      });

      expect(viejo.tieneDispositivo, isFalse);
      expect(viejo.puedeVincular(DateTime(2026)), isTrue);
    });

    test('el celular no se guarda con el resto del perfil', () {
      // Lo escribe `vincularDispositivo` con la hora del servidor, y las
      // reglas solo admiten ese cambio por separado.
      expect(perfil.toMap().containsKey('dispositivo_id'), isFalse);
      expect(perfil.toMap().containsKey('dispositivo_desde'), isFalse);
    });
  });
}
