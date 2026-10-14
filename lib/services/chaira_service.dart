import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/verificacion_result_model.dart';
import 'chaira_parser.dart';

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

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  ChairaService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

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
      final response = await _client
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
      return result.copyWith(imagenBytes: await _descargarFoto(result.fotoUrl!));
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
  Future<Uint8List?> _descargarFoto(String url) async {
    try {
      final response = await _client
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

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
