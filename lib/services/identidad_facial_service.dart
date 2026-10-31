import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'reconocimiento_facial_service.dart';

/// Lo que la verificación facial necesita para saber si quien está delante
/// es el dueño de la cuenta. Así [FaceVerificationViewModel] se prueba con un
/// falso, sin cámara ni modelo.
abstract class IdentidadFacial {
  /// El vector de la cara de la foto que se acaba de tomar, o null si en
  /// ella no hay exactamente una cara.
  Future<List<double>?> embeddingDeFoto(String ruta);

  /// La cara de referencia del estudiante en este celular, o null si todavía
  /// no se ha enrolado.
  Future<List<double>?> referencia();

  Future<void> guardarReferencia(List<double> embedding);

  /// El vector de la foto de Chairá, o null si no hay foto o no se ve una
  /// cara en ella.
  Future<List<double>?> embeddingDeChaira();

  Future<void> cerrar();
}

/// La referencia vive solo en este celular, cifrada por Android: ni la foto
/// ni el vector salen de él. Si se cambia el modelo, [_version] invalida las
/// referencias viejas, que ya no serían comparables.
class IdentidadEnCelular implements IdentidadFacial {
  static const _version = 'mobile_facenet_qaihub_v0.65.0';
  static const _almacen = FlutterSecureStorage();

  final String uid;

  /// La foto de Chairá solo hace falta para enrolarse, así que se pide
  /// cuando toca (puede que aún se esté descargando).
  final Future<Uint8List?> Function() fotoChaira;

  /// El modelo se empieza a cargar al crearla, para que esté listo cuando
  /// el estudiante termine el gesto.
  final Future<ReconocimientoFacialService> _reconocimiento;

  IdentidadEnCelular({required this.uid, required this.fotoChaira})
      : _reconocimiento = ReconocimientoFacialService.cargar() {
    // Si falla y nadie llega a usarlo (se cancela antes), que no quede como
    // error sin atender; quien lo use después recibe el error igual.
    _reconocimiento.ignore();
  }

  static String _clave(String uid) => 'rostro_$uid';

  /// Borra la cara de referencia de [uid] en este celular (desde Ajustes,
  /// para volver a enrolarse).
  static Future<void> olvidar(String uid) => _almacen.delete(key: _clave(uid));

  static Future<bool> tieneReferencia(String uid) async =>
      await _leer(uid) != null;

  static Future<List<double>?> _leer(String uid) async {
    final texto = await _almacen.read(key: _clave(uid));
    if (texto == null) return null;
    final datos = jsonDecode(texto) as Map<String, dynamic>;
    if (datos['version'] != _version) return null;
    return [for (final x in datos['vector'] as List) (x as num).toDouble()];
  }

  @override
  Future<List<double>?> embeddingDeFoto(String ruta) async =>
      (await _reconocimiento).embeddingDeArchivo(ruta);

  @override
  Future<List<double>?> referencia() => _leer(uid);

  @override
  Future<void> guardarReferencia(List<double> embedding) => _almacen.write(
        key: _clave(uid),
        value: jsonEncode({'version': _version, 'vector': embedding}),
      );

  @override
  Future<List<double>?> embeddingDeChaira() async {
    final foto = await fotoChaira();
    if (foto == null || foto.isEmpty) return null;
    return (await _reconocimiento).embeddingDeBytes(foto);
  }

  @override
  Future<void> cerrar() async {
    try {
      await (await _reconocimiento).cerrar();
    } catch (_) {
      // Si el modelo ni siquiera cargó, no hay nada que cerrar.
    }
  }
}
