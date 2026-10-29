import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/ble_service.dart';
import 'package:smart_check/services/ubicacion_service.dart';
import 'package:smart_check/viewmodels/radar_viewmodel.dart';

import 'curso_fakes.dart';

/// Aula de prueba en Florencia, Caquetá.
const aula = Geocerca(latitud: 1.62, longitud: -75.605, radioMetros: 50);

Position posicionEn(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class FakeUbicacionService implements UbicacionService {
  Position posicion = posicionEn(aula.latitud, aula.longitud);
  UbicacionException? fallo;

  @override
  Future<Position> posicionActual() async {
    if (fallo != null) throw fallo!;
    return posicion;
  }
}

class FakeBleService implements BleService {
  final _balizas = StreamController<BalizaDetectada>.broadcast();
  bool escaneando = false;
  BleException? fallo;

  /// Simula que el celular del docente oye al estudiante de esa clave.
  void oir(String clave, {int rssi = -55}) => _balizas.add(
        BalizaDetectada(huella: BleService.huellaDe(clave), rssi: rssi),
      );

  @override
  Stream<BalizaDetectada> escanear() {
    if (fallo != null) throw fallo!;
    escaneando = true;
    return _balizas.stream;
  }

  @override
  Future<void> detenerEscaneo() async => escaneando = false;

  @override
  Future<void> anunciar(String clave) async {}

  @override
  Future<void> dejarDeAnunciar() async {}
}

/// Un curso cuyo bloque de clase está en curso ahora mismo.
Curso cursoEnClase({Geocerca? geocerca, DateTime? ahora}) {
  final momento = ahora ?? DateTime.now();
  final inicio = momento.subtract(const Duration(minutes: 5));
  final fin = momento.add(const Duration(hours: 1));
  return Curso(
    id: 'c1',
    codigo: 'SIS-402',
    nombre: 'Arquitectura de Software',
    grupo: '302-B',
    aula: 'Aula 204',
    periodo: '2026-2',
    docenteUid: 'uid-docente',
    docenteNombre: 'ANA MARÍA PÉREZ GÓMEZ',
    horarios: [
      Horario(
        dia: momento.weekday,
        inicio: _hhmm(inicio),
        fin: _hhmm(fin),
      ),
    ],
    geocerca: geocerca,
  );
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

void main() {
  late FakeCursoService cursos;
  late FakeBleService ble;
  late FakeUbicacionService ubicacion;
  late RadarViewModel vm;

  setUp(() {
    cursos = FakeCursoService();
    cursos.inscritosPorCurso['c1'] = {
      '1117000000': const Inscrito(cedula: '1117000000', nombre: 'ANA PÉREZ'),
      'ca.munoz@udla.edu.co': const Inscrito(
        email: 'ca.munoz@udla.edu.co',
        nombre: 'CARLOS MUÑOZ',
      ),
    };
    ble = FakeBleService();
    ubicacion = FakeUbicacionService();
    vm = RadarViewModel(cursos: cursos, ble: ble, ubicacion: ubicacion);
  });

  tearDown(() => vm.dispose());

  group('huella BLE', () {
    test('es la misma para la misma clave, sin importar mayúsculas', () {
      expect(
        BleService.huellaDe('CA.Munoz@udla.edu.co'),
        BleService.huellaDe('ca.munoz@udla.edu.co'),
      );
    });

    test('distingue a dos estudiantes', () {
      expect(
        BleService.huellaDe('1117000000'),
        isNot(BleService.huellaDe('1117000001')),
      );
    });

    test('cabe en los 4 bytes del anuncio', () {
      expect(BleService.huellaDe('1117000000'), lessThan(0x100000000));
      expect(BleService.huellaDe('1117000000'), greaterThanOrEqualTo(0));
    });
  });

  group('condiciones para abrir el radar', () {
    test('fuera del horario no abre la clase', () async {
      final ahora = DateTime.now();
      final curso = Curso(
        id: 'c1',
        codigo: 'SIS-402',
        nombre: 'Arquitectura',
        grupo: '302-B',
        aula: 'Aula 204',
        periodo: '2026-2',
        docenteUid: 'uid-docente',
        docenteNombre: 'ANA',
        // Mismo día, pero una franja que ya pasó o aún no llega.
        horarios: [
          Horario(
            dia: ahora.weekday == 1 ? 2 : 1,
            inicio: '08:00',
            fin: '10:00',
          ),
        ],
      );

      expect(await vm.iniciar(curso, 'uid-docente'), isFalse);
      expect(vm.error, contains('Fuera del horario'));
      expect(ble.escaneando, isFalse);
      expect(cursos.sesionesPorCurso['c1'], anyOf(isNull, isEmpty));
    });

    test('fuera de la geocerca no abre la clase', () async {
      // ~1.1 km al norte del aula.
      ubicacion.posicion = posicionEn(aula.latitud + 0.01, aula.longitud);

      expect(
        await vm.iniciar(cursoEnClase(geocerca: aula), 'uid-docente'),
        isFalse,
      );
      expect(vm.error, contains('del aula'));
      expect(ble.escaneando, isFalse);
    });

    test('dentro de la geocerca y en horario sí abre', () async {
      expect(
        await vm.iniciar(cursoEnClase(geocerca: aula), 'uid-docente'),
        isTrue,
      );
      expect(vm.escaneando, isTrue);
      expect(vm.sesion, isNotNull);
      expect(vm.totalInscritos, 2);
      expect(vm.detectados, 0);
    });

    test('un curso sin geocerca no exige ubicación', () async {
      ubicacion.fallo = const UbicacionException('sin permiso');

      expect(await vm.iniciar(cursoEnClase(), 'uid-docente'), isTrue);
      expect(vm.escaneando, isTrue);
    });
  });

  group('asistencia por BLE', () {
    test('marca presente a quien se oye y deja al resto pendiente', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.detectados, 1);
      expect(vm.faltantes, 1);
      final ana = vm.lista.firstWhere((i) => i.inscrito.clave == '1117000000');
      expect(ana.detectado, isTrue);
      expect(ana.asistencia!.metodo, MetodoAsistencia.ble);
      expect(ana.asistencia!.estado, EstadoAsistencia.presente);
      expect(ana.rssi, -55);
    });

    test('ignora balizas que no son de sus inscritos', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('9999999999');
      await pumpEventQueue();

      expect(vm.detectados, 0);
    });

    test('oír dos veces al mismo no lo marca dos veces', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('1117000000');
      await pumpEventQueue();
      final primera = vm.lista.first.asistencia!.hora;
      ble.oir('1117000000', rssi: -70);
      await pumpEventQueue();

      expect(vm.detectados, 1);
      expect(vm.lista.first.asistencia!.hora, primera);
      expect(vm.lista.first.rssi, -70);
    });

    test('pasados 15 minutos del inicio se marca tarde', () async {
      final ahora = DateTime.now();
      final curso = Curso(
        id: 'c1',
        codigo: 'SIS-402',
        nombre: 'Arquitectura',
        grupo: '302-B',
        aula: 'Aula 204',
        periodo: '2026-2',
        docenteUid: 'uid-docente',
        docenteNombre: 'ANA',
        horarios: [
          Horario(
            dia: ahora.weekday,
            inicio: _hhmm(ahora.subtract(
              Duration(minutes: RadarViewModel.minutosParaTarde + 5),
            )),
            fin: _hhmm(ahora.add(const Duration(hours: 1))),
          ),
        ],
      );
      await vm.iniciar(curso, 'uid-docente');

      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.lista.first.asistencia!.estado, EstadoAsistencia.tarde);
    });

    test('el llamado manual marca ausente a quien no vino', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');
      final carlos = cursos.inscritosPorCurso['c1']!['ca.munoz@udla.edu.co']!;

      expect(await vm.marcarManual(carlos, presente: false), isTrue);

      final fila =
          vm.lista.firstWhere((i) => i.inscrito.clave == carlos.clave);
      expect(fila.asistencia!.estado, EstadoAsistencia.ausente);
      expect(fila.asistencia!.metodo, MetodoAsistencia.manual);
    });
  });

  test('detener cierra la sesión y apaga el escaneo', () async {
    await vm.iniciar(cursoEnClase(), 'uid-docente');
    final sesionId = vm.sesion!.id;

    await vm.detener();

    expect(vm.escaneando, isFalse);
    expect(ble.escaneando, isFalse);
    expect(
      cursos.sesionesPorCurso['c1']!.firstWhere((s) => s.id == sesionId).abierta,
      isFalse,
    );
  });

  test('volver a abrir el radar reusa la sesión de la franja', () async {
    final curso = cursoEnClase();
    await vm.iniciar(curso, 'uid-docente');
    final sesionId = vm.sesion!.id;
    await vm.detener();

    final otro = RadarViewModel(cursos: cursos, ble: ble, ubicacion: ubicacion);
    expect(await otro.iniciar(curso, 'uid-docente'), isTrue);

    // La misma sesión, reabierta: dos del mismo bloque contarían la clase
    // dos veces en la asistencia del estudiante.
    expect(otro.sesion!.id, sesionId);
    expect(cursos.sesionesPorCurso['c1']!.length, 1);
    expect(cursos.sesionesPorCurso['c1']!.single.abierta, isTrue);
    await otro.detener();
  });

  test('si no se puede reabrir, el radar abre otra sesión igual', () async {
    final curso = cursoEnClase();
    await vm.iniciar(curso, 'uid-docente');
    final sesionId = vm.sesion!.id;
    await vm.detener();
    cursos.reabrirProhibido = true;

    final otro = RadarViewModel(cursos: cursos, ble: ble, ubicacion: ubicacion);
    expect(await otro.iniciar(curso, 'uid-docente'), isTrue);

    expect(otro.error, isNull);
    expect(otro.sesion!.id, isNot(sesionId));
    expect(otro.sesion!.inicio, cursos.sesionesPorCurso['c1']!.first.inicio);
    await otro.detener();
  });
}
