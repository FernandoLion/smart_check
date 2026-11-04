import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/services/identidad_facial_service.dart';

void main() {
  group('IdentidadParaRegistro', () {
    test('no tiene referencia: la cuenta se está creando', () async {
      final identidad = IdentidadParaRegistro(fotoChaira: Uint8List(0));

      expect(await identidad.referencia(), isNull);
      await identidad.cerrar();
    });

    test('sin foto de Chairá no hay con qué comparar', () async {
      final identidad = IdentidadParaRegistro(fotoChaira: Uint8List(0));

      expect(await identidad.embeddingDeChaira(), isNull);
      await identidad.cerrar();
    });

    test('la cara que coincidió se queda en memoria hasta crear la cuenta',
        () async {
      final identidad = IdentidadParaRegistro(fotoChaira: Uint8List(0));
      expect(identidad.vector, isNull);

      await identidad.guardarReferencia(const [0.1, 0.2, 0.3]);

      expect(identidad.vector, const [0.1, 0.2, 0.3]);
      await identidad.cerrar();
    });
  });
}
