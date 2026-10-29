import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/verificacion_result_model.dart';
import 'chaira_parser.dart';

/// Cliente que confía, además de en las raíces del sistema, en la de Sectigo
/// con la que está firmado el certificado de Chairá.
///
/// Esa raíz (R46) es de 2021 y falta en el almacén de certificados de varios
/// Android todavía en uso, donde la consulta fallaba con
/// `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`.
/// Se añade a las del sistema, no se reemplazan: nada más queda de fiar.
class _ClienteConRaizSectigo {
  _ClienteConRaizSectigo._();

  static const _rutaRaiz = 'assets/certs/sectigo_r46.pem';
  static Future<http.Client>? _cliente;

  static Future<http.Client> obtener() => _cliente ??= _crear();

  static Future<http.Client> _crear() async {
    try {
      final pem = await rootBundle.load(_rutaRaiz);
      final contexto = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificatesBytes(pem.buffer.asUint8List());
      return IOClient(HttpClient(context: contexto));
    } catch (_) {
      // Si el asset no está, se sigue con las raíces del sistema.
      return http.Client();
    }
  }
}

/// Consulta los datos de una persona en Chairá (Universidad de la Amazonia).
///
/// Es la versión integrada de `consulta_carne.py`: en vez de abrir Chromium
/// con Playwright, envía la misma petición que dispara el botón "Buscar" de
/// VerificaCarne.aspx (un DirectEvent de Ext.NET) y lee la respuesta con
/// [ChairaParser]. No necesita Python, navegador ni servidor intermedio.
class ChairaService {
  static final Uri endpoint = Uri.parse(
    'https://chaira.uniamazonia.edu.co/Administrativo/Vistas/Publico/General/VerificaCarne.aspx',
  );

  final http.Client? _inyectado;
  final Duration timeout;

  ChairaService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _inyectado = client;

  /// El de las pruebas si lo hay; si no, el que confía en la raíz de Sectigo.
  Future<http.Client> get _cliente async =>
      _inyectado ?? await _ClienteConRaizSectigo.obtener();

  Future<VerificacionResult> verificarDocumento(String documento) async {
    final doc = documento.trim();
    // El campo de búsqueda de Chairá exige al menos 3 caracteres.
    if (doc.length < 3) {
      return VerificacionResult.fallido(
        doc,
        'El documento debe tener al menos 3 caracteres.',
      );
    }

    try {
      final cliente = await _cliente;
      final response = await cliente
          .post(
            endpoint,
            headers: const {
              'X-Requested-With': 'XMLHttpRequest',
              'X-Ext.Net': 'delta=true',
            },
            body: {
              '__EVENTTARGET': 'ctl03', // ResourceManager de la página
              '__EVENTARGUMENT': 'BBuscarPersona|event|Click',
              '__ExtNetDirectEventMarker': 'delta=true',
              'oTBusqueda': doc,
              // El servidor lee el documento de aquí; sin este parámetro
              // devuelve el primer registro de la base de datos.
              'submitDirectEventConfig': jsonEncode({
                'config': {
                  'extraParams': {'Parametro': doc},
                },
              }),
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return VerificacionResult.fallido(
          doc,
          'Chairá respondió con un error (HTTP ${response.statusCode}).',
        );
      }

      final result = ChairaParser.parse(
        doc,
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (!result.success || result.fotoUrl == null) return result;
      return result.copyWith(imagenBytes: await descargarFoto(result.fotoUrl!));
    } on TimeoutException {
      return VerificacionResult.fallido(
        doc,
        'Tiempo de espera agotado al consultar Chairá.',
      );
    } on http.ClientException {
      return VerificacionResult.fallido(
        doc,
        'No se pudo conectar con Chairá. Revisa tu conexión a internet.',
      );
    } catch (e) {
      return VerificacionResult.fallido(doc, 'Error al consultar Chairá: $e');
    }
  }

  /// La foto es opcional: si no llega a tiempo se muestra el avatar genérico.
  Future<Uint8List?> descargarFoto(String url) async {
    try {
      final cliente = await _cliente;
      final response = await cliente
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      final tipo = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 &&
          tipo.startsWith('image/') &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// El cliente propio se comparte entre instancias y vive lo que la app, y
  /// el inyectado lo cierra quien lo creó: aquí no hay nada que cerrar.
  void dispose() {}
}
