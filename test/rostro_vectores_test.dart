import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/utils/rostro_vectores.dart';

void main() {
  test('la similitud es el coseno, sin importar el largo', () {
    expect(similitud([1, 0], [5, 0]), closeTo(1, 1e-9));
    expect(similitud([1, 0], [0, 3]), closeTo(0, 1e-9));
    expect(similitud([1, 0], [-2, 0]), closeTo(-1, 1e-9));
    expect(similitud([1, 0], [0.8, 0.6]), closeTo(0.8, 1e-9));
  });

  test('normalizar deja el vector con largo 1', () {
    final n = normalizar([3, 4]);
    expect(n[0], closeTo(0.6, 1e-9));
    expect(n[1], closeTo(0.8, 1e-9));
  });

  test('vectores de distinto largo no se comparan', () {
    expect(() => similitud([1, 0], [1, 0, 0]), throwsArgumentError);
  });

  test('el recorte se centra en la cara y endereza los ojos', () {
    final r = recorteDe(
      const Rect.fromLTWH(100, 100, 100, 120),
      // Ojos a la misma altura: no hay que girar.
      ojoIzquierdo: const Offset(170, 150),
      ojoDerecho: const Offset(130, 150),
    );
    expect(r.centro, const Offset(150, 160));
    expect(r.lado, closeTo(120 * margenRecorte, 1e-9));
    expect(r.giro, closeTo(0, 1e-9));

    final inclinada = recorteDe(
      const Rect.fromLTWH(0, 0, 100, 100),
      ojoIzquierdo: const Offset(30, 30),
      ojoDerecho: const Offset(70, 70),
    );
    expect(inclinada.giro, closeTo(45, 1e-9));
  });

  test('muestrear sin giro copia la zona de la cara, de 0 a 1', () {
    // Foto de 4x4: mitad izquierda roja, mitad derecha azul.
    final rgb = Uint8List(4 * 4 * 3);
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        final i = (y * 4 + x) * 3;
        if (x < 2) {
          rgb[i] = 255;
        } else {
          rgb[i + 2] = 255;
        }
      }
    }
    final salida = muestrearCara(
      rgb,
      4,
      4,
      const RecorteCara(Offset(2, 2), 4, 0),
      tamano: 2,
    );
    // Por canal: [R(2x2), G(2x2), B(2x2)].
    expect(salida.sublist(0, 4), [1, 0, 1, 0]);
    expect(salida.sublist(4, 8), [0, 0, 0, 0]);
    expect(salida.sublist(8, 12), [0, 1, 0, 1]);
  });

  test('muestrear girado 180 grados invierte la imagen', () {
    final rgb = Uint8List(4 * 4 * 3);
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 2; x++) {
        rgb[(y * 4 + x) * 3] = 255;
      }
    }
    final salida = muestrearCara(
      rgb,
      4,
      4,
      const RecorteCara(Offset(2, 2), 4, 180),
      tamano: 2,
    );
    expect(salida.sublist(0, 4), [0, 1, 0, 1]);
  });
}
