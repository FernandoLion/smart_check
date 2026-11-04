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

  /// Guarda [embedding] como la cara de referencia de [uid] sin cargar el
  /// modelo: es para el registro, que ya comparó la cara antes de que la
  /// cuenta existiera.
  static Future<void> guardarPara(String uid, List<double> embedding) =>
      _almacen.write(
        key: _clave(uid),
        value: jsonEncode({'version': _version, 'vector': embedding}),
      );

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
  Future<void> guardarReferencia(List<double> embedding) =>
      guardarPara(uid, embedding);

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

/// Para el registro: la cuenta todavía no existe, así que no hay `uid` con el
/// que guardar la referencia. La cara se compara con la foto de Chairá que
/// ya bajó el paso 1, y si coincide el vector se queda aquí hasta que la
/// cuenta se cree; entonces se pasa a [IdentidadEnCelular.guardarPara].
class IdentidadParaRegistro implements IdentidadFacial {
  final Uint8List fotoChaira;
  final Future<ReconocimientoFacialService> _reconocimiento;

  List<double>? _chaira;
  bool _chairaLeida = false;
  List<double>? _vector;

  IdentidadParaRegistro({required this.fotoChaira})
      : _reconocimiento = ReconocimientoFacialService.cargar() {
    _reconocimiento.ignore();
  }

  /// La cara que coincidió con Chairá, o null si todavía no hay ninguna.
  List<double>? get vector => _vector;

  @override
  Future<List<double>?> embeddingDeFoto(String ruta) async =>
      (await _reconocimiento).embeddingDeArchivo(ruta);

  /// Nunca hay referencia: se está creando.
  @override
  Future<List<double>?> referencia() async => null;

  @override
  Future<void> guardarReferencia(List<double> embedding) async =>
      _vector = embedding;

  /// Se calcula una vez: la pantalla de registro la pide antes de abrir la
  /// cámara (para saber si hay con qué comparar) y la verificación otra vez.
  @override
  Future<List<double>?> embeddingDeChaira() async {
    if (!_chairaLeida) {
      _chaira = fotoChaira.isEmpty
          ? null
          : await (await _reconocimiento).embeddingDeBytes(fotoChaira);
      _chairaLeida = true;
    }
    return _chaira;
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
