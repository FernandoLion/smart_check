import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/rostro_vectores.dart';

/// Convierte la cara de una foto en el vector de MobileFaceNet
/// (`assets/models/mobile_facenet.tflite`) para compararla con otra.
///
/// Es la capa que toca los plugins (ML Kit para encontrar la cara, TFLite
/// para el modelo); la decisión de si es la misma persona la toma
/// [FaceVerificationViewModel] con [similitud].
class ReconocimientoFacialService {
  static const _modelo = 'assets/models/mobile_facenet.tflite';
  static const _tamano = 112;

  ReconocimientoFacialService._(this._interprete, this._porCanal);

  final Interpreter _interprete;

  /// El modelo de Qualcomm espera `[1, 3, 112, 112]`; si algún día se cambia
  /// por uno `[1, 112, 112, 3]`, se detecta al cargarlo.
  final bool _porCanal;

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      // En una foto suelta hay tiempo para el modo preciso.
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      minFaceSize: 0.1,
    ),
  );

  static Future<ReconocimientoFacialService> cargar() async {
    final interprete = await Interpreter.fromAsset(_modelo);
    final forma = interprete.getInputTensor(0).shape;
    return ReconocimientoFacialService._(interprete, forma.length == 4 && forma[1] == 3);
  }

  /// El vector de la cara de la foto en [ruta], o null si no hay
  /// exactamente una cara (con [soloUna]) o ninguna.
  Future<List<double>?> embeddingDeArchivo(
    String ruta, {
    bool soloUna = true,
  }) async {
    final caras = await _detector.processImage(InputImage.fromFilePath(ruta));
    if (caras.isEmpty || (soloUna && caras.length > 1)) return null;
    final cara = caras.reduce(
      (a, b) => a.boundingBox.width >= b.boundingBox.width ? a : b,
    );

    final decodificada = img.decodeImage(await File(ruta).readAsBytes());
    if (decodificada == null) return null;
    // ML Kit lee la orientación de la foto (EXIF): hay que aplicarla para que
    // la caja caiga en el mismo lugar.
    final foto = img.bakeOrientation(decodificada);
    final rgb = foto.getBytes(order: img.ChannelOrder.rgb);

    final recorte = recorteDe(
      cara.boundingBox,
      ojoIzquierdo: _punto(cara, FaceLandmarkType.leftEye),
      ojoDerecho: _punto(cara, FaceLandmarkType.rightEye),
    );
    final entrada = muestrearCara(
      rgb,
      foto.width,
      foto.height,
      recorte,
      tamano: _tamano,
      porCanal: _porCanal,
    );
    return _embedding(entrada);
  }

  /// El vector de la foto de Chairá, que llega en bytes y no como archivo.
  Future<List<double>?> embeddingDeBytes(Uint8List bytes) async {
    final carpeta = await Directory.systemTemp.createTemp('rostro');
    try {
      final archivo = File('${carpeta.path}/foto.jpg');
      await archivo.writeAsBytes(bytes);
      // En la foto de carné puede colarse otra cara (un sello, el fondo):
      // manda la más grande.
      return await embeddingDeArchivo(archivo.path, soloUna: false);
    } finally {
      await carpeta.delete(recursive: true);
    }
  }

  /// El modelo de Qualcomm compara dos caras a la vez (`img1`, `img2`); para
  /// sacar el vector de una sola se le da dos veces y se toma la primera fila.
  List<double> _embedding(Float32List entrada) {
    final bytes = entrada.buffer.asUint8List();
    final entradas = [
      for (var i = 0; i < _interprete.getInputTensors().length; i++) bytes,
    ];
    final forma = _interprete.getOutputTensor(0).shape;
    final salida = Uint8List(forma.fold(1, (t, d) => t * d) * 4);
    _interprete.runForMultipleInputs(entradas, {0: salida});
    final valores = salida.buffer.asFloat32List();
    final largo = forma.last;
    return normalizar([for (var i = 0; i < largo; i++) valores[i]]);
  }

  static Offset? _punto(Face cara, FaceLandmarkType tipo) {
    final p = cara.landmarks[tipo]?.position;
    return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
  }

  Future<void> cerrar() async {
    await _detector.close();
    _interprete.close();
  }
}
