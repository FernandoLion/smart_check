import 'dart:convert';
import 'dart:typed_data';

/// Modelo (M de MVVM) que representa el resultado de verificar un documento
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
      final iniciales = parts[0].substring(0, (parts[0].length >= 2) ? 2 : parts[0].length);
      final apellido = parts.length >= 4 ? parts[2] : parts[parts.length - 1];
      return '$iniciales.$apellido';
    } else if (parts.length == 2) {
      return '${parts[0][0]}.${parts[1]}';
    }
    return parts[0];
  }
}