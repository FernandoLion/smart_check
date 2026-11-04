import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

/// Matemática de la comparación facial, sin plugins para poder probarla.
///
/// MobileFaceNet convierte una cara en un vector ("embedding"): dos fotos de
/// la misma persona dan vectores que apuntan casi hacia el mismo lado, y la
/// similitud es el coseno del ángulo entre ellos (1: idénticos).

/// El vector con largo 1, para que solo cuente hacia dónde apunta.
List<double> normalizar(List<double> v) {
  final largo = sqrt(v.fold<double>(0, (t, x) => t + x * x));
  if (largo == 0) return List<double>.from(v);
  return [for (final x in v) x / largo];
}

/// Coseno del ángulo entre [a] y [b], de -1 a 1.
double similitud(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) {
    throw ArgumentError('Los vectores deben tener el mismo largo.');
  }
  final na = normalizar(a);
  final nb = normalizar(b);
  var producto = 0.0;
  for (var i = 0; i < na.length; i++) {
    producto += na[i] * nb[i];
  }
  return producto.clamp(-1.0, 1.0);
}

/// La referencia facial del estudiante en su celular, que se afina con el uso.
///
/// Una sola foto de referencia sale con una luz y un ángulo; con el tiempo el
/// dueño pasa con más esfuerzo cuanto más distinta es la situación. Por eso
/// se guardan también algunas verificaciones buenas, y se compara contra el
/// promedio de todas.
///
/// - [ancla]: la cara con la que se enroló, la que se validó contra Chairá.
///   Nunca se reemplaza: fija hasta dónde puede derivar la referencia.
/// - [recientes]: las últimas verificaciones que pasaron con holgura, hasta
///   [maxRecientes]. Al llegar una más, sale la más vieja.
class GaleriaRostro {
  final List<double> ancla;
  final List<List<double>> recientes;

  static const maxRecientes = 4;

  /// Para aprender una cara no basta con que pase: tiene que parecerse con
  /// holgura a la referencia actual **y** al ancla. Si no, un impostor que
  /// pasara raspando podría, verificación a verificación, ir corriendo la
  /// referencia hacia su propia cara (envenenamiento de plantilla).
  static const umbralParaAprender = 0.60;
  static const umbralAnclaParaAprender = 0.50;

  const GaleriaRostro(this.ancla, [this.recientes = const []]);

  /// El promedio de todas las caras guardadas, con largo 1. Cada una pesa lo
  /// mismo sin importar el largo de su vector.
  List<double> get centroide {
    final suma = List<double>.filled(ancla.length, 0);
    for (final v in [ancla, ...recientes]) {
      final n = normalizar(v);
      for (var i = 0; i < suma.length; i++) {
        suma[i] += n[i];
      }
    }
    return normalizar(suma);
  }

  /// La galería con [vivo] aprendido, o null si no se parece lo bastante
  /// para fiarse de ella.
  GaleriaRostro? aprender(List<double> vivo) {
    if (similitud(vivo, centroide) < umbralParaAprender) return null;
    if (similitud(vivo, ancla) < umbralAnclaParaAprender) return null;
    final nuevas = [...recientes, vivo];
    while (nuevas.length > maxRecientes) {
      nuevas.removeAt(0);
    }
    return GaleriaRostro(ancla, nuevas);
  }

  Map<String, dynamic> toMap() => {
        'formato': 2,
        'ancla': ancla,
        'recientes': recientes,
      };

  /// Lee las dos formas en que se ha guardado: la galería, y el vector
  /// suelto de antes, que pasa a ser el ancla sin recientes (así nadie tiene
  /// que volver a enrolarse).
  static GaleriaRostro? fromMap(Map<String, dynamic> datos) {
    List<double> vector(Object? v) =>
        [for (final x in v as List) (x as num).toDouble()];
    if (datos['ancla'] != null) {
      return GaleriaRostro(vector(datos['ancla']), [
        for (final r in (datos['recientes'] as List? ?? const [])) vector(r),
      ]);
    }
    if (datos['vector'] != null) return GaleriaRostro(vector(datos['vector']));
    return null;
  }
}

/// Qué parte de la foto recortar para entregarle la cara al modelo: un
/// cuadrado centrado en la cara y el giro que endereza la línea de los ojos.
class RecorteCara {
  final Offset centro;
  final double lado;

  /// Grados que hay que girar la foto para que los ojos queden horizontales.
  final double giro;

  const RecorteCara(this.centro, this.lado, this.giro);
}

/// Margen alrededor de la caja de ML Kit, que corta la frente y el mentón
/// muy al ras. MobileFaceNet se entrenó con algo de contorno.
const margenRecorte = 1.15;

RecorteCara recorteDe(Rect caja, {Offset? ojoIzquierdo, Offset? ojoDerecho}) {
  var giro = 0.0;
  if (ojoIzquierdo != null && ojoDerecho != null) {
    // En la foto el ojo izquierdo de la persona queda a la derecha.
    final izq = ojoIzquierdo.dx <= ojoDerecho.dx ? ojoIzquierdo : ojoDerecho;
    final der = identical(izq, ojoIzquierdo) ? ojoDerecho : ojoIzquierdo;
    giro = atan2(der.dy - izq.dy, der.dx - izq.dx) * 180 / pi;
  }
  final lado = max(caja.width, caja.height) * margenRecorte;
  return RecorteCara(caja.center, lado, giro);
}

/// Recorta, endereza y escala la cara de una sola pasada: cada píxel de la
/// salida ([tamano]×[tamano]) se lee de la foto girada [RecorteCara.giro]
/// alrededor del centro, con interpolación bilineal.
///
/// [rgb] son los píxeles de la foto, 3 bytes por píxel. La salida va de 0 a
/// 1, por canal (`[3][tamano][tamano]`, como pide el modelo de Qualcomm) o
/// por píxel (`[tamano][tamano][3]`) según [porCanal].
Float32List muestrearCara(
  Uint8List rgb,
  int ancho,
  int alto,
  RecorteCara recorte, {
  int tamano = 112,
  bool porCanal = true,
}) {
  final salida = Float32List(3 * tamano * tamano);
  final rad = recorte.giro * pi / 180;
  final cosA = cos(rad);
  final sinA = sin(rad);
  final escala = recorte.lado / tamano;
  final plano = tamano * tamano;

  double canal(int x, int y, int c) {
    final cx = x.clamp(0, ancho - 1);
    final cy = y.clamp(0, alto - 1);
    return rgb[(cy * ancho + cx) * 3 + c].toDouble();
  }

  for (var v = 0; v < tamano; v++) {
    for (var u = 0; u < tamano; u++) {
      // Del centro del píxel de salida a la foto: escalar y girar.
      final dx = (u + 0.5 - tamano / 2) * escala;
      final dy = (v + 0.5 - tamano / 2) * escala;
      final sx = recorte.centro.dx + dx * cosA - dy * sinA - 0.5;
      final sy = recorte.centro.dy + dx * sinA + dy * cosA - 0.5;
      final x0 = sx.floor();
      final y0 = sy.floor();
      final fx = sx - x0;
      final fy = sy - y0;
      for (var c = 0; c < 3; c++) {
        final arriba = canal(x0, y0, c) * (1 - fx) + canal(x0 + 1, y0, c) * fx;
        final abajo =
            canal(x0, y0 + 1, c) * (1 - fx) + canal(x0 + 1, y0 + 1, c) * fx;
        final valor = (arriba * (1 - fy) + abajo * fy) / 255;
        final i = v * tamano + u;
        salida[porCanal ? c * plano + i : i * 3 + c] = valor;
      }
    }
  }
  return salida;
}
