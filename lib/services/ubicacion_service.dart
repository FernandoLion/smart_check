import 'package:geolocator/geolocator.dart';

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
