/// Roles con los que un usuario puede entrar a la app.
class Rol {
  static const docente = 'docente';
  static const estudiante = 'estudiante';
}

/// Modelo (la M de MVVM) del perfil del usuario.
///
/// Firebase Auth solo sabe el correo y la contraseña. Quién es la persona y
/// con qué roles entra se guarda aparte, en Firestore (`usuarios/{uid}`), y
/// se lee al iniciar sesión.
class UsuarioPerfil {
  final String uid;
  final String email;
  final String nombre;
  final List<String> roles;

  const UsuarioPerfil({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.roles,
  });

  /// Arma el perfil con el documento que devuelve Firestore. Si un campo
  /// falta, se usa un valor vacío en vez de fallar.
  factory UsuarioPerfil.fromMap(String uid, Map<String, dynamic> map) {
    return UsuarioPerfil(
      uid: uid,
      email: map['email'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      roles: List<String>.from(map['roles'] as List? ?? const []),
    );
  }

  bool get esDocente => roles.contains(Rol.docente);
  bool get esEstudiante => roles.contains(Rol.estudiante);

  /// Docente que también cursa materias: es el único caso en que se pregunta
  /// con qué perfil entrar.
  bool get esDual => esDocente && esEstudiante;
}
