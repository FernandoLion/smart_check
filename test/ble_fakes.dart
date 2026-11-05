import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/services/ble_service.dart';
import 'package:smart_check/services/dispositivo_service.dart';
import 'package:smart_check/services/ubicacion_service.dart';

/// Fakes del hardware (BLE y GPS), que comparten el radar del docente y la
/// baliza del estudiante.

/// Aula de prueba en Florencia, Caquetá.
const aula = Geocerca(latitud: 1.62, longitud: -75.605, radioMetros: 50);

Position posicionEn(
  double lat,
  double lng, {
  double precision = 5,
  DateTime? hora,
  bool simulada = false,
}) =>
    Position(
      latitude: lat,
      longitude: lng,
      timestamp: hora ?? DateTime(2026),
      accuracy: precision,
      isMocked: simulada,
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

  /// La precisión que pidió quien preguntó la última vez.
  double? precisionPedida;

  /// Como el servicio de verdad: la lectura pasa por [elegirLectura], así
  /// que una posición imprecisa o simulada se rechaza igual.
  @override
  Future<Position> posicionActual({
    double precisionMaxima = UbicacionService.precisionMaxima,
  }) async {
    precisionPedida = precisionMaxima;
    if (fallo != null) throw fallo!;
    return elegirLectura(
      [posicion],
      ahora: posicion.timestamp,
      precisionMaxima: precisionMaxima,
    );
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
  String id = 'c1',
  Geocerca? geocerca,
  DateTime? ahora,
  Duration empezoHace = const Duration(minutes: 5),
  Duration termina = const Duration(hours: 1),
  int? dia,
}) {
  final momento = ahora ?? DateTime.now();
  return Curso(
    id: id,
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

/// Un celular con un identificador fijo, o ninguno si la plataforma no lo da.
class FakeDispositivoService implements DispositivoService {
  FakeDispositivoService([this.id = celularDePrueba]);
  final String? id;

  @override
  Future<String?> identificador() async => id;
}

/// El celular que tiene vinculado la cuenta en los tests.
const celularDePrueba = 'android-1234567890';
