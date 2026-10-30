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
  final String? fotoUrl;
  final Uint8List? imagenBytes;
  final String? error;

  /// El usuario institucional que Chairá tiene registrado para el documento,
  /// o null si no se pudo consultar. No se guarda en la base: es el dato con
  /// el que se arma el correo al registrarse.
  final String? usuarioChaira;

  const VerificacionResult({
    required this.success,
    required this.documentoConsultado,
    this.nombre,
    this.cedula,
    this.programa,
    this.tipoUsuario,
    this.fotoUrl,
    this.imagenBytes,
    this.error,
    this.usuarioChaira,
  });

  /// Construye un resultado fallido con el mensaje [error].
  const VerificacionResult.fallido(this.documentoConsultado, this.error)
      : success = false,
        nombre = null,
        cedula = null,
        programa = null,
        tipoUsuario = null,
        fotoUrl = null,
        imagenBytes = null,
        usuarioChaira = null;

  /// Lee el JSON que imprime `consulta_carne.py`.
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
      fotoUrl: json['foto_url'] as String?,
      imagenBytes: imgBytes,
      error: json['error'] as String?,
    );
  }

  VerificacionResult copyWith({
    Uint8List? imagenBytes,
    String? usuarioChaira,
  }) {
    return VerificacionResult(
      success: success,
      documentoConsultado: documentoConsultado,
      nombre: nombre,
      cedula: cedula,
      programa: programa,
      tipoUsuario: tipoUsuario,
      fotoUrl: fotoUrl,
      imagenBytes: imagenBytes ?? this.imagenBytes,
      error: error,
      usuarioChaira: usuarioChaira ?? this.usuarioChaira,
    );
  }

  /// Chairá devuelve el tipo en mayúsculas ("DOCENTE", "DOCENTE CATEDRA"...).
  bool get esDocente => tipoUsuario?.toUpperCase().contains('DOCENTE') ?? false;

  /// El usuario del correo institucional: el que Chairá tiene registrado si
  /// se pudo consultar, y si no el que se deduce del nombre.
  String? get username => usuarioChaira ?? _usuarioDeducido;

  /// Si el usuario viene de Chairá y no de deducirlo del nombre. Solo
  /// entonces el correo es un dato verificado.
  bool get correoVerificado => usuarioChaira != null;

  /// Deduce un nombre de usuario a partir del nombre completo.
  /// Ejemplo: "Ana María Pérez Gómez" -> "an.perez"
  ///
  /// Es el respaldo de cuando Chairá no contesta: se equivoca con los
  /// homónimos y con algunos nombres compuestos, así que nunca se guarda
  /// como si fuera un correo verificado.
  String? get _usuarioDeducido {
    if (nombre == null || nombre!.trim().isEmpty) return null;
    final parts = _sinTildes(nombre!.trim().toLowerCase())
        .split(RegExp(r'\s+'))
        .map((p) => p.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length >= 3) {
      final iniciales = parts[0].substring(0, (parts[0].length >= 2) ? 2 : parts[0].length);
      final apellido = parts.length >= 4 ? parts[2] : parts[parts.length - 1];
      return '$iniciales.$apellido';
    } else if (parts.length == 2) {
      return '${parts[0][0]}.${parts[1]}';
    }
    return parts[0];
  }

  /// Quita tildes y diéresis para que el usuario sea válido en un correo.
  static String _sinTildes(String texto) {
    const conTilde = 'áàäâéèëêíìïîóòöôúùüûñç';
    const sinTilde = 'aaaaeeeeiiiioooouuuunc';
    final buffer = StringBuffer();
    for (final char in texto.split('')) {
      final i = conTilde.indexOf(char);
      buffer.write(i >= 0 ? sinTilde[i] : char);
    }
    return buffer.toString();
  }
}
