import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/services/ubicacion_service.dart';

import 'ble_fakes.dart';

void main() {
  final ahora = DateTime(2026, 11, 5, 10);

  group('elegirLectura', () {
    test('se queda con la más precisa', () {
      final mejor = elegirLectura(
        [
          posicionEn(1, 1, precision: 25, hora: ahora),
          posicionEn(2, 2, precision: 6, hora: ahora),
          posicionEn(3, 3, precision: 12, hora: ahora),
        ],
        ahora: ahora,
      );

      expect(mejor.latitude, 2);
    });

    test('descarta la posición vieja que el sistema tenía guardada', () {
      // La caché dice "en el aula" con muy buena precisión, pero es de hace
      // diez minutos: el estudiante ya se fue.
      final mejor = elegirLectura(
        [
          posicionEn(1, 1,
              precision: 3,
              hora: ahora.subtract(const Duration(minutes: 10))),
          posicionEn(2, 2, precision: 9, hora: ahora),
        ],
        ahora: ahora,
      );

      expect(mejor.latitude, 2);
    });

    test('con el reloj del celular desfasado usa lo que haya', () {
      final mejor = elegirLectura(
        [posicionEn(1, 1, precision: 8, hora: DateTime(2020))],
        ahora: ahora,
      );

      expect(mejor.latitude, 1);
    });

    test('rechaza la ubicación aproximada aunque caiga en el aula', () {
      expect(
        () => elegirLectura(
          [posicionEn(1, 1, precision: 1800, hora: ahora)],
          ahora: ahora,
        ),
        throwsA(
          isA<UbicacionException>()
              .having((e) => e.mensaje, 'mensaje', contains('±1800 m')),
        ),
      );
    });

    test('con un radio grande acepta una lectura igual de gruesa', () {
      final mejor = elegirLectura(
        [posicionEn(1, 1, precision: 80, hora: ahora)],
        ahora: ahora,
        precisionMaxima: 100,
      );

      expect(mejor.accuracy, 80);
    });

    test('rechaza la ubicación simulada', () {
      expect(
        () => elegirLectura(
          [
            posicionEn(1, 1, precision: 4, hora: ahora, simulada: true),
            posicionEn(2, 2, precision: 9, hora: ahora),
          ],
          ahora: ahora,
        ),
        throwsA(
          isA<UbicacionException>()
              .having((e) => e.mensaje, 'mensaje', contains('simulada')),
        ),
      );
    });

    test('sin lecturas avisa que el GPS no respondió', () {
      expect(
        () => elegirLectura(const [], ahora: ahora),
        throwsA(isA<UbicacionException>()),
      );
    });
  });

  group('comprobarAula', () {
    test('sin geocerca no pregunta la ubicación', () async {
      final ubicacion = FakeUbicacionService()
        ..fallo = const UbicacionException('no debería preguntar');

      expect(await comprobarAula(ubicacion, null), isNull);
    });

    test('dice a cuántos metros quedó y si está dentro', () async {
      final ubicacion = FakeUbicacionService()
        // ~111 m al norte del centro; el radio es de 50 m.
        ..posicion = posicionEn(aula.latitud + 0.001, aula.longitud,
            precision: 7);

      final resultado = (await comprobarAula(ubicacion, aula))!;

      expect(resultado.distancia, 111);
      expect(resultado.precision, 7);
      expect(resultado.dentro, isFalse);
      expect(resultado.metrosFuera, 61);
      expect(resultado.estasA, 'Estás a 61 m del aula (GPS ±7 m)');
    });

    test('con un radio pequeño exige la precisión mínima', () async {
      final ubicacion = FakeUbicacionService();
      const pequena = Geocerca(latitud: 1.62, longitud: -75.605, radioMetros: 10);

      await comprobarAula(ubicacion, pequena);
      expect(ubicacion.precisionPedida, UbicacionService.precisionMaxima);

      await comprobarAula(
        ubicacion,
        const Geocerca(latitud: 1.62, longitud: -75.605, radioMetros: 100),
      );
      expect(ubicacion.precisionPedida, 100);
    });
  });
}
