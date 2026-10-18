/// Estudiante inscrito en un curso (`cursos/{id}/inscritos/{clave}`).
///
/// El docente lo agrega por CSV, por cédula o por correo, así que puede
/// faltar uno de los dos. [uid] queda null hasta que el estudiante se registre.
class Inscrito {
  final String? cedula;
  final String? email;
  final String nombre;
  final String? uid;

  const Inscrito({this.cedula, this.email, required this.nombre, this.uid})
      : assert(cedula != null || email != null);

  factory Inscrito.fromMap(Map<String, dynamic> map) => Inscrito(
        cedula: map['cedula'] as String?,
        email: map['email'] as String?,
        nombre: map['nombre'] as String? ?? '',
        uid: map['uid'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'cedula': cedula,
        'email': email,
        'nombre': nombre,
        'uid': uid,
      };

  /// Id del documento: la cédula si se conoce, si no el correo.
  String get clave => cedula ?? email!.toLowerCase();

  /// Valores con los que el estudiante puede encontrar el curso.
  List<String> get claves => [
        ?cedula,
        if (email != null) email!.toLowerCase(),
      ];
}
