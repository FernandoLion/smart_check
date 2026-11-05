import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/curso_service.dart';
import 'package:smart_check/services/ubicacion_service.dart';
import 'package:smart_check/viewmodels/beacon_viewmodel.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

void main() {
  late FakeCursoService cursos;
  late FakeBleService ble;
  late FakeUbicacionService ubicacion;
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
    vm = BeaconViewModel(
      cursos: cursos,
      ble: ble,
      ubicacion: ubicacion,
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

  test('con el GPS impreciso no anuncia, aunque diga que está en el aula',
      () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    // Justo en el centro, pero con ±2 km de error: es lo que da la ubicación
    // aproximada, y así parecería que todo el barrio está en clase.
    ubicacion.posicion =
        posicionEn(aula.latitud, aula.longitud, precision: 2000);

    expect(await marcar([enAula]), isFalse);

    expect(vm.error, contains('±2000 m'));
    expect(ble.anunciando, isNull);
    expect(cursos.presenciasPorSesion, isEmpty);
  });

  test('con una ubicación simulada no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    ubicacion.posicion =
        posicionEn(aula.latitud, aula.longitud, simulada: true);

    expect(await marcar([enAula]), isFalse);

    expect(vm.error, contains('simulada'));
    expect(ble.anunciando, isNull);
  });

  test('la firma lleva a cuántos metros del aula estaba', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    // ~22 m al norte del centro, dentro del radio de 50 m.
    ubicacion.posicion =
        posicionEn(aula.latitud + 0.0002, aula.longitud, precision: 8);

    expect(await marcar([enAula]), isTrue);

    final firma = cursos.presenciasPorSesion['llamado-1']!.single;
    expect(firma.distanciaAula, 22);
    expect(firma.precisionGps, 8);
    expect(firma.toMap()['distancia_aula'], 22);
    expect(vm.aula!.dentro, isTrue);
  });

  test('sin geocerca la firma no inventa la distancia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await marcar([cursoEnClase()]), isTrue);

    final mapa = cursos.presenciasPorSesion['llamado-1']!.single.toMap();
    expect(mapa.containsKey('distancia_aula'), isFalse);
    expect(mapa.containsKey('precision_gps'), isFalse);
  });

  test('si el docente cierra el llamado, deja de anunciar', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];
    expect(await marcar([enAula]), isTrue);
    expect(ble.anunciando, '1117000000');

    // El docente detiene el radar antes de que se acabe la ventana.
    await cursos.cerrarSesion('c1', 'llamado-1');
    await pumpEventQueue();

    expect(ble.anunciando, isNull);
    expect(vm.anunciando, isFalse);
    expect(vm.cerradoPorDocente, isTrue);
    expect(vm.ventanaVencida, isFalse);
  });

  test('si se cierra otro llamado, sigue anunciando', () async {
    cursos.sesionesPorCurso['c1'] = [
      llamadoAbierto(),
      llamadoAbierto(id: 'otro'),
    ];
    expect(await marcar([enAula]), isTrue);

    await cursos.cerrarSesion('c1', 'otro');
    await pumpEventQueue();

    expect(ble.anunciando, '1117000000');
    expect(vm.cerradoPorDocente, isFalse);
  });

  test('sin celular vinculado no anuncia', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await marcar([enAula], vinculado: null), isFalse);

    expect(vm.error, contains('vincúlalo'));
    expect(ble.anunciando, isNull);
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
    expect(firma.toMap().containsKey('biometria'), isFalse);
    // El orden importa: cuando el radar oiga la baliza, la firma ya está, y
    // sin ella el servidor le rechazaría la asistencia al docente.
    expect(ble.anunciando, '1117000000');
  });

  test('la firma lleva cómo se verificó su rostro', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(
      await vm.marcar(
        [enAula],
        '1117000000',
        dispositivoVinculado: celularDePrueba,
        vinculadoEn: atado,
        rostro: 'enrolado',
        similitudRostro: 0.61234,
      ),
      isTrue,
    );

    final firma = cursos.presenciasPorSesion['llamado-1']!.single;
    expect(firma.rostro, 'enrolado');
    expect(firma.rostroRecienEnrolado, isTrue);
    // Se guarda redondeada: es para calibrar, no hace falta más.
    expect(firma.toMap()['similitud_rostro'], 0.612);
    expect(firma.toMap()['rostro'], 'enrolado');
  });

  test('sin verificación facial la firma no inventa el campo', () async {
    cursos.sesionesPorCurso['c1'] = [llamadoAbierto()];

    expect(await marcar([enAula]), isTrue);

    final mapa = cursos.presenciasPorSesion['llamado-1']!.single.toMap();
    expect(mapa.containsKey('rostro'), isFalse);
    expect(mapa.containsKey('similitud_rostro'), isFalse);
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
}
