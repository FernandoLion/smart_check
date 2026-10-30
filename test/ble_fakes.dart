import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/services/ble_service.dart';
import 'package:smart_check/services/ubicacion_service.dart';

/// Fakes del hardware (BLE y GPS), que comparten el radar del docente y la
/// baliza del estudiante.

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

  /// La clave que está anunciando el celular del estudiante, o null.
  String? anunciando;
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
  Future<void> anunciar(String clave) async {
    if (fallo != null) throw fallo!;
    anunciando = clave;
  }

  @override
  Future<void> dejarDeAnunciar() async => anunciando = null;
}

/// Un curso cuyo bloque de clase está en curso ahora mismo.
Curso cursoEnClase({
  Geocerca? geocerca,
  DateTime? ahora,
  Duration empezoHace = const Duration(minutes: 5),
  Duration termina = const Duration(hours: 1),
  int? dia,
}) {
  final momento = ahora ?? DateTime.now();
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
        dia: dia ?? momento.weekday,
        inicio: hhmm(momento.subtract(empezoHace)),
        fin: hhmm(momento.add(termina)),
      ),
    ],
    geocerca: geocerca,
  );
}

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
