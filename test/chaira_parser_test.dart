import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/services/chaira_parser.dart';

import 'chaira_fixtures.dart';

void main() {
  group('ChairaParser', () {
    test('extrae los datos de una persona encontrada', () {
      final r = ChairaParser.parse('1117000000', respuestaExito());

      expect(r.success, isTrue);
      expect(r.documentoConsultado, '1117000000');
      expect(r.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
      expect(r.cedula, '1117000000');
      expect(r.programa, 'INGENIERÍA DE SISTEMAS');
      expect(r.tipoUsuario, 'ESTUDIANTE');
      expect(r.fotoUrl, fotoUrlHttp.replaceFirst('http://', 'https://'));
      expect(r.error, isNull);
    });

    test('sin mongoid no hay foto', () {
      final r = ChairaParser.parse('1117000000', respuestaExito(mongoid: ''));

      expect(r.success, isTrue);
      expect(r.fotoUrl, isNull);
    });

    test('devuelve el mensaje de Chairá cuando no encuentra a la persona', () {
      final r = ChairaParser.parse('999', respuestaNoEncontrado);

      expect(r.success, isFalse);
      expect(r.nombre, isNull);
      expect(
        r.error,
        'No fue posible encontrar una persona asociada a ese parámetro',
      );
    });

    test('lee respuestas JSON sin <textarea> y con escapes \\u', () {
      const body =
          r'{"script":"App.DFNombre.setText(\"JOSÉ \\\"PEPE\\\" DÍAZ\",true);App.DFCedula.setText(\"123\",true);"}';
      final r = ChairaParser.parse('123', body);

      expect(r.success, isTrue);
      expect(r.nombre, 'JOSÉ "PEPE" DÍAZ');
      expect(r.cedula, '123');
      expect(r.programa, isNull);
    });

    test('ignora los textos de plantilla de los controles', () {
      const body =
          '<textarea>{script:&quot;App.DFNombre.setText(\\&quot;NOMBRE\\&quot;);&quot;}</textarea>';
      final r = ChairaParser.parse('123', body);

      expect(r.success, isFalse);
      expect(r.error, ChairaParser.mensajeNoEncontrado);
    });

    test('lee mensajes de Ext.Msg.alert', () {
      const body =
          '<textarea>{script:&quot;Ext.Msg.alert(\\&quot;Advertencia\\&quot;,\\&quot;Servicio no disponible\\&quot;);&quot;}</textarea>';
      final r = ChairaParser.parse('123', body);

      expect(r.success, isFalse);
      expect(r.error, 'Servicio no disponible');
    });

    test('lee errores del servidor de Ext.NET', () {
      const body =
          '<textarea>{success:false,errorMessage:&quot;Object reference not set&quot;}</textarea>';
      final r = ChairaParser.parse('123', body);

      expect(r.success, isFalse);
      expect(r.error, 'Object reference not set');
    });

    test('marca como inesperada una respuesta vacía o HTML', () {
      for (final body in ['<textarea>{}</textarea>', '<html><body></body></html>']) {
        final r = ChairaParser.parse('123', body);
        expect(r.success, isFalse);
        expect(r.error, ChairaParser.mensajeRespuestaInesperada);
      }
    });
  });
}
