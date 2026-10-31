import 'dart:ui' show Offset, Rect, Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Lo que ML Kit ve en un fotograma, reducido a lo que decide la
/// verificación: cuántas caras hay, cuánto ocupan y qué están haciendo.
class RostroVisto {
  final int rostros;

  /// Qué fracción del ancho del cuadro ocupa la cara. Por debajo de un
  /// mínimo no se puede juzgar nada: un parpadeo a dos metros no se ve.
  final double tamano;

  /// Probabilidad de que cada ojo esté abierto (0 a 1), o null cuando ML Kit
  /// no se atreve a decirlo (poca luz, cara de perfil...).
  final double? ojoIzquierdo;
  final double? ojoDerecho;

  /// Giro de la cabeza sobre el eje vertical, en grados. El signo depende de
  /// hacia dónde mire, así que quien lo usa mira el valor absoluto.
  final double? giroHorizontal;

  /// Id con el que ML Kit sigue a la misma cara de un fotograma al
  /// siguiente. Si cambia a mitad del gesto, es otra persona.
  final int? seguimiento;

  /// Dónde está la cara en el fotograma ya enderezado, y sus ojos (para
  /// enderezarla antes de reconocerla).
  final Rect? caja;
  final Offset? centroOjoIzquierdo;
  final Offset? centroOjoDerecho;

  const RostroVisto({
    this.rostros = 0,
    this.tamano = 0,
    this.ojoIzquierdo,
    this.ojoDerecho,
    this.giroHorizontal,
    this.seguimiento,
    this.caja,
    this.centroOjoIzquierdo,
    this.centroOjoDerecho,
  });

  /// Un fotograma donde no hay nadie.
  static const nadie = RostroVisto();
}

/// Envuelve el detector de rostros de ML Kit.
///
/// Como [BleService], es la capa que toca el plugin: la lógica de la
/// verificación vive en el viewmodel, que así se puede probar sin cámara.
class RostroService {
  RostroService() : _detector = FaceDetector(options: _opciones);

  static final _opciones = FaceDetectorOptions(
    // `fast` basta para saber si hay una cara y si parpadeó, y mantiene la
    // vista fluida; `accurate` es para medir los puntos del rostro.
    performanceMode: FaceDetectorMode.fast,
    // La clasificación es la que da la probabilidad de ojo abierto, o sea la
    // prueba de vida: sin esto una foto impresa pasaría igual.
    enableClassification: true,
    enableTracking: true,
    // Los ojos sirven para enderezar la cara antes de reconocerla.
    enableLandmarks: true,
    minFaceSize: 0.2,
  );

  final FaceDetector _detector;

  Future<RostroVisto> analizar(InputImage imagen, Size cuadro) async {
    final caras = await _detector.processImage(imagen);
    if (caras.isEmpty) return RostroVisto.nadie;
    // Si hay alguien de fondo manda quien está delante, que es el más grande.
    final cara = caras.reduce(
      (a, b) => a.boundingBox.width >= b.boundingBox.width ? a : b,
    );
    final ancho = cuadro.width <= 0 ? 1.0 : cuadro.width;
    return RostroVisto(
      rostros: caras.length,
      tamano: cara.boundingBox.width / ancho,
      ojoIzquierdo: cara.leftEyeOpenProbability,
      ojoDerecho: cara.rightEyeOpenProbability,
      giroHorizontal: cara.headEulerAngleY,
      seguimiento: cara.trackingId,
      caja: cara.boundingBox,
      centroOjoIzquierdo: _punto(cara, FaceLandmarkType.leftEye),
      centroOjoDerecho: _punto(cara, FaceLandmarkType.rightEye),
    );
  }

  static Offset? _punto(Face cara, FaceLandmarkType tipo) {
    final p = cara.landmarks[tipo]?.position;
    return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
  }

  Future<void> cerrar() => _detector.close();
}
