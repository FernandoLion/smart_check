import 'dart:math' show sqrt1_2;
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

  group('GaleriaRostro', () {
    const ancla = [1.0, 0.0];
    const casiAncla = [0.8, 0.6]; // coseno 0.8 con el ancla

    test('sin recientes, la referencia es el ancla', () {
      final c = const GaleriaRostro(ancla).centroide;
      expect(c[0], closeTo(1, 1e-9));
      expect(c[1], closeTo(0, 1e-9));
    });

    test('el centroide pesa cada cara igual, sin importar su largo', () {
      final c = const GaleriaRostro([2.0, 0.0], [
        [0.0, 10.0],
      ]).centroide;
      expect(c[0], closeTo(sqrt1_2, 1e-9));
      expect(c[1], closeTo(sqrt1_2, 1e-9));
    });

    test('aprende una cara que se parece con holgura', () {
      final nueva = const GaleriaRostro(ancla).aprender(casiAncla);

      expect(nueva, isNotNull);
      expect(nueva!.ancla, ancla);
      expect(nueva.recientes, [casiAncla]);
    });

    test('no aprende una que pasó raspando', () {
      // Coseno 0.55: pasaría el umbral de identidad, no el de aprender.
      expect(const GaleriaRostro(ancla).aprender([0.55, 0.835]), isNull);
    });

    test('el ancla frena a quien va corriendo la referencia', () {
      // Recientes ya desviadas hacia otra cara: el centroide se parece al
      // impostor, pero el ancla no.
      const desviada = [0.6, 0.8];
      const galeria = GaleriaRostro(ancla, [
        desviada,
        desviada,
        desviada,
        desviada,
      ]);
      const impostor = [0.3, 0.954];
      expect(similitud(impostor, galeria.centroide),
          greaterThan(GaleriaRostro.umbralParaAprender));

      expect(galeria.aprender(impostor), isNull);
    });

    test('guarda las últimas cuatro y nunca suelta el ancla', () {
      GaleriaRostro galeria = const GaleriaRostro(ancla);
      for (var i = 0; i < 6; i++) {
        galeria = galeria.aprender([0.9, 0.1 * i])!;
      }

      expect(galeria.recientes, hasLength(GaleriaRostro.maxRecientes));
      expect(galeria.recientes.first, [0.9, 0.2]);
      expect(galeria.recientes.last, [0.9, 0.5]);
      expect(galeria.ancla, ancla);
    });

    test('ida y vuelta por el almacén', () {
      final galeria = const GaleriaRostro(ancla, [casiAncla]);
      final leida = GaleriaRostro.fromMap(galeria.toMap())!;

      expect(leida.ancla, ancla);
      expect(leida.recientes, [casiAncla]);
    });

    test('una referencia guardada con el formato viejo pasa a ser el ancla',
        () {
      final leida = GaleriaRostro.fromMap({
        'version': 'mobile_facenet_qaihub_v0.65.0',
        'vector': [0.5, 0.5],
      })!;

      expect(leida.ancla, [0.5, 0.5]);
      expect(leida.recientes, isEmpty);
    });

    test('sin datos de cara no hay galería', () {
      expect(GaleriaRostro.fromMap({'version': 'x'}), isNull);
    });
  });
}
