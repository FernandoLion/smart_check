import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_check/models/verificacion_result_model.dart';
import 'package:smart_check/services/chaira_service.dart';

import 'chaira_fixtures.dart';

final _fotoJpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

http.Response _html(String body) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );

void main() {
  group('ChairaService', () {
    test('envía el DirectEvent de "Buscar" con el documento', () async {
      late http.Request enviado;
      final service = ChairaService(
        client: MockClient((request) async {
          if (request.method == 'GET') return http.Response('', 404);
          enviado = request;
          return _html(respuestaNoEncontrado);
        }),
      );

      await service.verificarDocumento('  1117000000 ');

      expect(enviado.method, 'POST');
      expect(enviado.url, ChairaService.endpoint);
      expect(enviado.headers['X-Ext.Net'], 'delta=true');
      final campos = enviado.bodyFields;
      expect(campos['__EVENTTARGET'], 'ctl03');
      expect(campos['__EVENTARGUMENT'], 'BBuscarPersona|event|Click');
      expect(campos['oTBusqueda'], '1117000000');
      expect(
        jsonDecode(campos['submitDirectEventConfig']!),
        {
          'config': {
            'extraParams': {'Parametro': '1117000000'},
          },
        },
      );
    });

    test('devuelve los datos y descarga la foto por https', () async {
      Uri? urlFoto;
      final service = ChairaService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            urlFoto = request.url;
            return http.Response.bytes(
              _fotoJpeg,
              200,
              headers: {'content-type': 'image/jpeg'},
            );
          }
          return _html(respuestaExito());
        }),
      );

      final r = await service.verificarDocumento('1117000000');

      expect(r.success, isTrue);
      expect(r.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
      expect(r.programa, 'INGENIERÍA DE SISTEMAS');
      expect(urlFoto.toString(), fotoUrlHttp.replaceFirst('http://', 'https://'));
      expect(r.imagenBytes, _fotoJpeg);
    });

    test('si la foto falla, la verificación sigue siendo exitosa', () async {
      final service = ChairaService(
        client: MockClient((request) async {
          if (request.method == 'GET') return _html('<html></html>');
          return _html(respuestaExito());
        }),
      );

      final r = await service.verificarDocumento('1117000000');

      expect(r.success, isTrue);
      expect(r.imagenBytes, isNull);
    });

    test('no consulta Chairá con documentos de menos de 3 caracteres', () async {
      var llamadas = 0;
      final service = ChairaService(
        client: MockClient((request) async {
          llamadas++;
          return _html(respuestaExito());
        }),
      );

      final r = await service.verificarDocumento(' 12 ');

      expect(r.success, isFalse);
      expect(r.error, contains('al menos 3'));
      expect(llamadas, 0);
    });

    test('informa errores HTTP', () async {
      final service = ChairaService(
        client: MockClient((_) async => http.Response('', 503)),
      );

      final r = await service.verificarDocumento('1117000000');

      expect(r.success, isFalse);
      expect(r.error, contains('HTTP 503'));
    });

    test('informa la falta de conexión', () async {
      final service = ChairaService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      final r = await service.verificarDocumento('1117000000');

      expect(r.success, isFalse);
      expect(r.error, contains('conexión'));
    });

    test('informa el tiempo de espera agotado', () async {
      final service = ChairaService(
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => Completer<http.Response>().future),
      );

      final r = await service.verificarDocumento('1117000000');

      expect(r.success, isFalse);
      expect(r.error, contains('Tiempo de espera'));
    });
  });

  group('VerificacionResult', () {
    VerificacionResult conNombre(String nombre, {String? tipo}) =>
        VerificacionResult(
          success: true,
          documentoConsultado: '1',
          nombre: nombre,
          tipoUsuario: tipo,
        );

    test('genera usuarios de correo sin tildes ni eñes', () {
      expect(conNombre('ANA MARÍA PÉREZ GÓMEZ').username, 'an.perez');
      expect(conNombre('Carlos Andrés Muñoz Rivera').username, 'ca.munoz');
      expect(conNombre(' NÚÑEZ  ORDÓÑEZ ').username, 'n.ordonez');
    });

    test('reconoce docentes sin importar mayúsculas', () {
      expect(conNombre('X', tipo: 'DOCENTE').esDocente, isTrue);
      expect(conNombre('X', tipo: 'Docente catedra').esDocente, isTrue);
      expect(conNombre('X', tipo: 'ESTUDIANTE').esDocente, isFalse);
      expect(conNombre('X').esDocente, isFalse);
    });
  });
}
