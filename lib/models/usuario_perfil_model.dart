import 'dart:typed_data';

import 'verificacion_result_model.dart';

/// Roles con los que un usuario puede entrar a la app.
class Rol {
  static const docente = 'docente';
  static const estudiante = 'estudiante';
}

/// Modelo (M de MVVM) del perfil del usuario registrado.
///
/// Se guarda en Firestore (`usuarios/{uid}`) al registrarse, con los datos
/// verificados en Chairá, y se lee al iniciar sesión para saber quién es el
/// usuario y con qué roles puede entrar.
class UsuarioPerfil {
  final String uid;
  final String email;
  final String nombre;
  final String? cedula;
  final String? programa;
  final String? tipoUsuario;
  final String? fotoUrl;
  final List<String> roles;

  const UsuarioPerfil({
    required this.uid,
    required this.email,
    required this.nombre,
    this.cedula,
    this.programa,
    this.tipoUsuario,
    this.fotoUrl,
    required this.roles,
  });

  /// Crea el perfil a partir de la verificación en Chairá. Los docentes son
  /// también estudiantes solo si activaron "También curso materias".
  factory UsuarioPerfil.desdeVerificacion({
    required String uid,
    required String email,
    required VerificacionResult verificacion,
    bool tambienEstudiante = false,
  }) {
    return UsuarioPerfil(
      uid: uid,
      email: email,
      nombre: verificacion.nombre ?? '',
      cedula: verificacion.cedula ?? verificacion.documentoConsultado,
      programa: verificacion.programa,
      tipoUsuario: verificacion.tipoUsuario,
      fotoUrl: verificacion.fotoUrl,
      roles: verificacion.esDocente
          ? [Rol.docente, if (tambienEstudiante) Rol.estudiante]
          : [Rol.estudiante],
    );
  }

  factory UsuarioPerfil.fromMap(String uid, Map<String, dynamic> map) {
    return UsuarioPerfil(
      uid: uid,
      email: map['email'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      cedula: map['cedula'] as String?,
      programa: map['programa'] as String?,
      tipoUsuario: map['tipo_usuario'] as String?,
      fotoUrl: map['foto_url'] as String?,
      roles: List<String>.from(map['roles'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'nombre': nombre,
        'cedula': cedula,
        'programa': programa,
        'tipo_usuario': tipoUsuario,
        'foto_url': fotoUrl,
        'roles': roles,
      };

  bool get esDocente => roles.contains(Rol.docente);
  bool get esEstudiante => roles.contains(Rol.estudiante);

  /// Docente que también cursa materias: es el único caso en que se pregunta
  /// con qué perfil entrar.
  bool get esDual => esDocente && esEstudiante;

  /// Datos del usuario en el formato que usan las tarjetas de identidad.
  VerificacionResult comoVerificacion({Uint8List? imagenBytes}) {
    return VerificacionResult(
      success: true,
      documentoConsultado: cedula ?? '',
      nombre: nombre,
      cedula: cedula,
      programa: programa,
      tipoUsuario: tipoUsuario,
      fotoUrl: fotoUrl,
      imagenBytes: imagenBytes,
    );
  }
}
