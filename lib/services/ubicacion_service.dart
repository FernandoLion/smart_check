import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
/// clase si está en el aula que le asignó al curso, y el estudiante solo
/// marca si está ahí.
///
/// Un aula se distingue del pasillo por pocos metros, así que no basta con
/// "una ubicación": tiene que ser la precisa (Android 12 deja dar solo la
/// aproximada, que se equivoca por kilómetros y pone a todo el barrio en el
/// mismo punto), reciente, no simulada y con un margen de error pequeño.
class UbicacionService {
  /// Peor que esto, el GPS no distingue el aula de lo que hay alrededor: se
  /// pide esperar en vez de dar por buena una posición que puede estar en
  /// cualquier parte de ese círculo.
  static const precisionMaxima = 30.0;

  /// Lo más que se espera a que el GPS afine. Las primeras lecturas suelen
  /// venir de la red o de la caché, con decenas de metros de error.
  static const _ventana = Duration(seconds: 10);

  /// Con esta precisión ya no vale la pena esperar más.
  static const _suficiente = 12.0;

  /// La última lectura buena y cuándo se tomó. Marcar pregunta dos veces
  /// (al tocar "Registrar asistencia" y antes de emitir, con la cara en
  /// medio): sin esto esperaría el GPS dos veces seguidas. En medio minuto
  /// nadie sale del aula a otra parte.
  static Position? _ultima;
  static DateTime? _ultimaEn;
  static const _reuso = Duration(seconds: 30);

  /// Si la posición que da el sistema es de hace más que esto, es la de
  /// donde estaba antes, no la de ahora.
  static const maximaEdad = Duration(seconds: 30);

  Future<Position> posicionActual({
    double precisionMaxima = precisionMaxima,
  }) async {
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
    await _exigirUbicacionPrecisa();

    final previa = _ultima;
    final previaEn = _ultimaEn;
    if (previa != null &&
        previaEn != null &&
        DateTime.now().difference(previaEn) <= _reuso &&
        previa.accuracy <= precisionMaxima) {
      return previa;
    }

    final lecturas = await _leerDuranteUnRato();
    final mejor = elegirLectura(
      lecturas,
      ahora: DateTime.now(),
      precisionMaxima: precisionMaxima,
    );
    _ultima = mejor;
    _ultimaEn = DateTime.now();
    return mejor;
  }

  /// Con solo la ubicación aproximada, el celular reporta un punto fijo de
  /// una cuadrícula de kilómetros: dos teléfonos del mismo barrio quedan "en
  /// el aula" aunque uno esté en su casa. Se le pide al sistema la precisa
  /// (Android muestra su propio diálogo) y, si no la da, no se sigue.
  static Future<void> _exigirUbicacionPrecisa() async {
    try {
      if (await Geolocator.getLocationAccuracy() !=
          LocationAccuracyStatus.reduced) {
        return;
      }
      await Geolocator.requestPermission();
      if (await Geolocator.getLocationAccuracy() !=
          LocationAccuracyStatus.reduced) {
        return;
      }
    } catch (_) {
      // La plataforma no lo dice: lo juzga la precisión de cada lectura.
      return;
    }
    throw const UbicacionException(
      'SmartCheck solo tiene tu ubicación aproximada, que se equivoca por '
      'kilómetros. En los ajustes del celular, entra a Aplicaciones → '
      'SmartCheck → Permisos → Ubicación y activa "Usar ubicación precisa".',
    );
  }

  /// Junta lecturas hasta que una sea lo bastante precisa o se acabe la
  /// ventana.
  static Future<List<Position>> _leerDuranteUnRato() async {
    final lecturas = <Position>[];
    final listo = Completer<void>();
    Object? fallo;
    final suscripcion = Geolocator.getPositionStream(
      locationSettings: _ajustes(),
    ).listen(
      (p) {
        lecturas.add(p);
        if (p.accuracy <= _suficiente && !listo.isCompleted) listo.complete();
      },
      onError: (Object e) {
        fallo = e;
        if (!listo.isCompleted) listo.complete();
      },
    );
    await listo.future.timeout(_ventana, onTimeout: () {});
    await suscripcion.cancel();
    if (lecturas.isEmpty && fallo != null) {
      throw UbicacionException('No se pudo leer tu ubicación: $fallo');
    }
    return lecturas;
  }

  static LocationSettings _ajustes() =>
      defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 1),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            );
}

/// De las [lecturas] que dio el GPS, la que vale para juzgar si se está en
/// el aula: la más precisa de las recientes. Lanza [UbicacionException] si
/// no hay ninguna, si alguna es simulada o si ni la mejor es lo bastante
/// precisa.
///
/// Si ninguna es reciente según el reloj del celular (que puede estar mal
/// puesto), se usan todas: es preferible eso a no dejar marcar nunca.
@visibleForTesting
Position elegirLectura(
  List<Position> lecturas, {
  required DateTime ahora,
  double precisionMaxima = UbicacionService.precisionMaxima,
}) {
  if (lecturas.isEmpty) {
    throw const UbicacionException(
      'El GPS no respondió a tiempo. Revisa que la ubicación esté encendida '
      'y vuelve a intentarlo.',
    );
  }
  if (lecturas.any((p) => p.isMocked)) {
    throw const UbicacionException(
      'Tu celular está usando una ubicación simulada. Desactívala para '
      'comprobar el aula.',
    );
  }
  final recientes = lecturas
      .where(
        (p) => ahora.difference(p.timestamp) <= UbicacionService.maximaEdad,
      )
      .toList();
  final candidatas = recientes.isEmpty ? lecturas : recientes;
  final mejor = candidatas.reduce((a, b) => b.accuracy < a.accuracy ? b : a);
  if (mejor.accuracy > precisionMaxima) {
    throw UbicacionException(
      'El GPS todavía no sabe bien dónde estás (±${mejor.accuracy.round()} '
      'm). Acércate a una ventana o a un lugar más abierto, espera unos '
      'segundos y vuelve a intentarlo.',
    );
  }
  return mejor;
}

/// Dónde quedó el celular respecto al aula, en metros.
class ComprobacionAula {
  /// Del celular al centro del aula.
  final int distancia;

  /// El margen de error del GPS en esa lectura (±).
  final int precision;

  /// El radio de la geocerca.
  final int radio;

  const ComprobacionAula({
    required this.distancia,
    required this.precision,
    required this.radio,
  });

  bool get dentro => distancia <= radio;

  /// Lo que falta para entrar al radio; 0 si ya se está dentro.
  int get metrosFuera => max(0, distancia - radio);

  /// "Estás a 40 m del aula (GPS ±8 m)", para los mensajes de rechazo.
  String get estasA =>
      'Estás a $metrosFuera m del aula (GPS ±$precision m)';
}

/// Comprueba dónde está el celular respecto a la [geocerca], o null si el
/// curso no tiene aula fijada.
///
/// Lo preguntan el radar del docente antes de abrir el llamado y la baliza
/// del estudiante antes de emitir, así que vive junto al servicio y no dentro
/// de uno de los dos viewmodels. Con un radio grande se admite una lectura
/// igual de gruesa; con uno pequeño se exige al menos [UbicacionService.
/// precisionMaxima].
Future<ComprobacionAula?> comprobarAula(
  UbicacionService ubicacion,
  Geocerca? geocerca,
) async {
  if (geocerca == null) return null;
  final posicion = await ubicacion.posicionActual(
    precisionMaxima: max(UbicacionService.precisionMaxima, geocerca.radioMetros),
  );
  return ComprobacionAula(
    distancia: geocerca.distanciaA(posicion.latitude, posicion.longitude).round(),
    precision: posicion.accuracy.round(),
    radio: geocerca.radioMetros.round(),
  );
}
