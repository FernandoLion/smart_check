import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/biometria_service.dart';
import 'package:smart_check/services/curso_service.dart';
import 'package:smart_check/services/ubicacion_service.dart';
import 'package:smart_check/viewmodels/beacon_viewmodel.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

void main() {
  late FakeCursoService cursos;
  late FakeBleService ble;
  late FakeUbicacionService ubicacion;
  late FakeBiometriaService biometria;
  late BeaconViewModel vm;
  // El celular que la cuenta tiene atado, y desde cuándo.
  final atado = DateTime(2026, 3, 1, 8);
  late Curso enAula;

  /// Un llamado abierto de diez minutos, como el que acaba de abrir el
  /// docente.
  Sesion llamadoAbierto({String id = 'llamado-1'}) {
    final ahora = DateTime.now();
    return Sesion(
      id: id,
      inicio: ahora.subtract(const Duration(minutes: 1)),
      fin: ahora.add(const Duration(minutes: 9)),
      bloqueInicio: ahora.subtract(const Duration(minutes: 5)),
    );
  }

  Sesion llamadoVencido() {
    final ahora = DateTime.now();
    return Sesion(
      id: 'vencido',
      inicio: ahora.subtract(const Duration(minutes: 20)),
      fin: ahora.subtract(const Duration(minutes: 10)),
    );
  }

  setUp(() {
    cursos = FakeCursoService();
    enAula = cursoEnClase(geocerca: aula);
    ble = FakeBleService();
    ubicacion = FakeUbicacionService();
    biometria = FakeBiometriaService();
    vm = BeaconViewModel(
      cursos: cursos,
      ble: ble,
      ubicacion: ubicacion,
      biometria: biometria,
      dispositivos: FakeDispositivoService(),
    );
  });

  tearDown(() => vm.dispose());

  /// Marcar con la cuenta atada a este mismo celular, que es el caso normal.
  Future<bool> marcar(List<Curso> lista, {String? vinculado = celularDePrueba}) =>
      vm.marcar(
        lista,
        '1117000000',
        dispositivoVinculado: vinculado,
        vinculadoEn: vinculado == null ? null : atado,
      );

  test('sin llamado abierto avisa y no anuncia nada', () async {
    expect(await marcar([enAula]), isFalse);

    expect(vm.error, contains('llamado abierto'));
    expect(ble.anunciando, isNull);
    expect(vm.anunciando, isFalse);
  });

  test('un llamado que ya venció tampoco sirve', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoVencido()];

    expect(await marcar([enAula]), isFalse);

    expect(ble.anunciando, isNull);
  });

  test('con el llamado abierto anuncia su clave', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await marcar([enAula]), isTrue);

    expect(vm.anunciando, isTrue);
    expect(ble.anunciando, '1117000000');
    expect(vm.curso!.id, 'c1');
    expect(vm.minutosRestantes, greaterThan(0));
    expect(vm.ventanaVencida, isFalse);
  });

  test('fuera del aula no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    // ~1.1 km al norte del aula.
    ubicacion.posicion = posicionEn(aula.latitud + 0.01, aula.longitud);

    expect(await marcar([enAula]), isFalse);

    expect(vm.error, contains('del aula'));
    expect(ble.anunciando, isNull);
  });

  test('un curso sin aula fijada no exige ubicación', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    ubicacion.fallo = const UbicacionException('sin permiso');

    expect(await marcar([cursoEnClase()]), isTrue);

    expect(ble.anunciando, '1117000000');
  });

  test('parar deja de anunciar', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    await marcar([enAula]);

    await vm.parar();

    expect(vm.anunciando, isFalse);
    expect(ble.anunciando, isNull);
    // Lo paró el estudiante, no el reloj.
    expect(vm.ventanaVencida, isFalse);
  });

  test('al acabarse la ventana deja de anunciar solo', () async {
    final ahora = DateTime.now();
    // Una ventana que se cierra en un instante, para no esperar diez minutos.
    cursos.sesionesPorCurso['c1'] = [
      Sesion(
        id: 'llamado-1',
        inicio: ahora.subtract(const Duration(minutes: 1)),
        fin: ahora.add(const Duration(milliseconds: 40)),
      ),
    ];
    await marcar([enAula]);
    expect(ble.anunciando, '1117000000');

    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(vm.ventanaVencida, isTrue);
    expect(vm.anunciando, isFalse);
    expect(ble.anunciando, isNull);
    expect(vm.minutosRestantes, 0);
  });

  test('elige la materia cuyo llamado está vigente', () async {
    final otra = cursoEnClase(id: 'c2', geocerca: aula);
    cursos.sesionesPorCurso['c1'] = [llamadoVencido()];
    cursos.sesionesPorCurso['c2'] = [llamadoAbierto(id: 'llamado-2')];

    expect(await marcar([enAula, otra]), isTrue);

    expect(vm.curso!.id, 'c2');
    expect(vm.sesion!.id, 'llamado-2');
  });

  test('si el celular no reconoce a su dueño, no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    biometria.resultado = ResultadoBiometria.rechazada;

    expect(await marcar([enAula]), isFalse);

    expect(vm.error, contains('confirmar que eres tú'));
    expect(ble.anunciando, isNull);
  });

  test('un celular sin huella ni PIN sí marca, pero queda dicho', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    biometria.resultado = ResultadoBiometria.noDisponible;

    expect(await marcar([enAula]), isTrue);

    expect(ble.anunciando, '1117000000');
    expect(vm.biometriaUsada, ResultadoBiometria.noDisponible);
    expect(vm.biometriaUsada!.comoDato, 'no_disponible');
  });

  test('no se le pide la huella a quien está lejos del aula', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    ubicacion.posicion = posicionEn(aula.latitud + 0.01, aula.longitud);

    await marcar([enAula]);

    // Sería cruel pedirle el dedo para después decirle que está a un
    // kilómetro: la ubicación va antes porque es inmediata.
    expect(biometria.veces, 0);
  });

  test('tampoco si no hay ningún llamado abierto', () async {
    await marcar([enAula]);

    expect(biometria.veces, 0);
  });

  test('sin celular vinculado no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await marcar([enAula], vinculado: null), isFalse);

    expect(vm.error, contains('vincúlalo'));
    expect(ble.anunciando, isNull);
    expect(biometria.veces, 0);
  });

  test('desde el celular de otro no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    // La cuenta está atada a otro teléfono: este es prestado.
    expect(await marcar([enAula], vinculado: 'android-del-amigo'), isFalse);

    expect(vm.error, contains('otro celular'));
    expect(ble.anunciando, isNull);
    expect(cursos.presenciasPorSesion, isEmpty);
  });

  test('firma su presencia antes de anunciarse', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await marcar([enAula]), isTrue);

    final firma = cursos.presenciasPorSesion['llamado-1']!.single;
    expect(firma.claveInscrito, '1117000000');
    expect(firma.dispositivo, celularDePrueba);
    expect(firma.vinculadoEn, atado);
    expect(firma.biometria, 'biometrica');
    // El orden importa: cuando el radar oiga la baliza, la firma ya está, y
    // sin ella el servidor le rechazaría la asistencia al docente.
    expect(ble.anunciando, '1117000000');
  });

  test('si el servidor rechaza la firma, no se anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    cursos.falloAlFirmar = const CursoException(
      'No se pudo firmar tu asistencia: permiso denegado en la base de datos.',
      'permission-denied',
    );

    expect(await marcar([enAula]), isFalse);

    expect(ble.anunciando, isNull);
    expect(vm.error, contains('firmar tu asistencia'));
  });

  test('sin huella ni PIN la firma lo deja dicho', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    biometria.resultado = ResultadoBiometria.noDisponible;

    expect(await marcar([enAula]), isTrue);

    expect(
      cursos.presenciasPorSesion['llamado-1']!.single.biometria,
      'no_disponible',
    );
  });
}
