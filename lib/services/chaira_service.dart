import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/verificacion_result_model.dart';

class ChairaService {
  final String baseUrl;

  ChairaService({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    return 'http://10.0.2.2:5000';
  }

  Future<VerificacionResult> verificarDocumento(String documento) async {
    final uri = Uri.parse('$baseUrl/api/verificar');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'documento': documento.trim()}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VerificacionResult.fromJson(json);
      } else if (response.statusCode == 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VerificacionResult(
          success: false,
          documentoConsultado: documento,
          error: json['error'] as String? ?? 'Solicitud inválida.',
        );
      } else {
        return VerificacionResult(
          success: false,
          documentoConsultado: documento,
          error: 'Error del servidor (HTTP ${response.statusCode}).',
        );
      }
    } on http.ClientException catch (e) {
      return VerificacionResult(
        success: false,
        documentoConsultado: documento,
        error: 'No se pudo conectar al servidor: ${e.message}',
      );
    } catch (e) {
      return VerificacionResult(
        success: false,
        documentoConsultado: documento,
        error: 'Error de conexión: $e',
      );
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}