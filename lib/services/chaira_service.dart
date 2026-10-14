import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Modelo de datos que representa el resultado de verificar un documento
/// en el sistema CHAIRA de la Universidad de la Amazonia.
class VerificacionResult {
  final bool success;
  final String documentoConsultado;
  final String? nombre;
  final String? cedula;
  final String? programa;
  final String? tipoUsuario;
  final Uint8List? imagenBytes;
  final String? error;

  const VerificacionResult({
    required this.success,
    required this.documentoConsultado,
    this.nombre,
    this.cedula,
    this.programa,
    this.tipoUsuario,
    this.imagenBytes,
    this.error,
  });

  factory VerificacionResult.fromJson(Map<String, dynamic> json) {
    Uint8List? imgBytes;
    final b64 = json['imagen_base64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      imgBytes = base64Decode(b64);
    }

    return VerificacionResult(
      success: json['success'] as bool? ?? false,
      documentoConsultado: json['documento_consultado'] as String? ?? '',
      nombre: json['nombre'] as String?,
      cedula: json['cedula'] as String?,
      programa: json['programa'] as String?,
      tipoUsuario: json['tipo_usuario'] as String?,
      imagenBytes: imgBytes,
      error: json['error'] as String?,
    );
  }

  /// Genera un nombre de usuario a partir del nombre completo.
  /// Ejemplo: "Jhojan Fernando Leon Claros" -> "jh.leon"
  String? get username {
    if (nombre == null || nombre!.isEmpty) return null;
    final parts = nombre!.toLowerCase().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      // Primeras 2 letras del primer nombre + '.' + primer apellido
      final iniciales = parts[0].substring(0, (parts[0].length >= 2) ? 2 : parts[0].length);
      // El primer apellido suele estar después de los nombres
      // Heurística: si hay 4+ partes, el apellido es la 3ra; si hay 3, es la 3ra
      final apellido = parts.length >= 4 ? parts[2] : parts[parts.length - 1];
      return '$iniciales.$apellido';
    } else if (parts.length == 2) {
      return '${parts[0][0]}.${parts[1]}';
    }
    return parts[0];
  }
}

/// Servicio que se comunica con el backend SmartCheck API (server.py)
/// para verificar documentos contra el sistema CHAIRA.
class ChairaService {
  /// URL base del servidor backend.
  /// En desarrollo local: http://10.0.2.2:5000 (Android emulator)
  /// o http://localhost:5000 (Web/Desktop)
  /// En producción: la URL de tu servidor desplegado.
  final String baseUrl;

  ChairaService({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    // 10.0.2.2 es el alias de localhost del host desde el emulador Android.
    // Para dispositivo físico en la misma red, usa la IP local del PC.
    // Para Flutter web o desktop, usa localhost directamente.
    return 'http://10.0.2.2:5000';
  }

  /// Verifica un documento contra el sistema CHAIRA.
  /// Retorna un [VerificacionResult] con los datos del estudiante/funcionario.
  Future<VerificacionResult> verificarDocumento(String documento) async {
    final uri = Uri.parse('$baseUrl/api/verificar');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'documento': documento.trim()}),
      ).timeout(const Duration(seconds: 45));

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

  /// Verifica que el servidor backend esté disponible.
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
