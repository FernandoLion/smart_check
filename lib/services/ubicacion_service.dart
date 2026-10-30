import 'package:geolocator/geolocator.dart';

import '../models/curso_model.dart';

/// Error de ubicación con un mensaje listo para mostrar.
class UbicacionException implements Exception {
  final String mensaje;
  const UbicacionException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Dónde está el celular. Se usa para la geocerca: el docente solo abre la
/// clase si está en el aula que le asignó al curso.
class UbicacionService {
  static const _tiempoMaximo = Duration(seconds: 20);

  Future<Position> posicionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UbicacionException(
        'Activa la ubicación del celular para comprobar el aula.',
      );
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const UbicacionException(
        'Dale permiso de ubicación a SmartCheck desde los ajustes del '
        'celular.',
      );
    }
    if (permiso == LocationPermission.denied) {
      throw const UbicacionException(
        'Sin permiso de ubicación no se puede comprobar el aula.',
      );
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _tiempoMaximo,
        ),
      );
    } catch (e) {
      throw UbicacionException('No se pudo leer tu ubicación: $e');
    }
  }
}

/// Metros que faltan para estar dentro de la geocerca, o null si ya se está
/// dentro o si el curso no tiene aula fijada.
///
/// Lo preguntan el radar del docente antes de abrir el llamado y la baliza
/// del estudiante antes de emitir, así que vive junto al servicio y no dentro
/// de uno de los dos viewmodels.
Future<int?> metrosFueraDelAula(
  UbicacionService ubicacion,
  Geocerca? geocerca,
) async {
  if (geocerca == null) return null;
  final posicion = await ubicacion.posicionActual();
  if (geocerca.contiene(posicion.latitude, posicion.longitude)) return null;
  return geocerca.distanciaA(posicion.latitude, posicion.longitude).round();
}
