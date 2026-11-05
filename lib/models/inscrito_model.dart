import 'package:cloud_firestore/cloud_firestore.dart';

/// Estudiante inscrito en un curso (`cursos/{id}/inscritos/{clave}`).
///
/// El docente lo agrega por CSV, por cédula o por correo, así que puede
/// faltar uno de los dos. [uid] queda null hasta que el estudiante se registre.
class Inscrito {
  final String? cedula;
  final String? email;
  final String nombre;
  final String? uid;

  /// Cuándo lo inscribió el docente (hora del servidor). Las clases
  /// anteriores no le cuentan como falta: todavía no estaba en el curso.
  /// null en los inscritos de antes de guardarla, a los que les cuenta todo.
  final DateTime? inscritoEn;

  const Inscrito({
    this.cedula,
    this.email,
    required this.nombre,
    this.uid,
    this.inscritoEn,
  }) : assert(cedula != null || email != null);

  factory Inscrito.fromMap(Map<String, dynamic> map) => Inscrito(
        cedula: map['cedula'] as String?,
        email: map['email'] as String?,
        nombre: map['nombre'] as String? ?? '',
        uid: map['uid'] as String?,
        inscritoEn: (map['inscrito_en'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'cedula': cedula,
        'email': email,
        'nombre': nombre,
        'uid': uid,
      };

  /// Si la clase que empezó en [franja] le cuenta: no si fue antes de
  /// inscribirlo. Quien vino igual a una clase anterior la tiene a favor;
  /// eso lo decide quien suma, que sabe si vino.
  bool debiaVenir(DateTime franja) =>
      inscritoEn == null || !franja.isBefore(inscritoEn!);

  /// Id del documento: la cédula si se conoce, si no el correo.
  String get clave => cedula ?? email!.toLowerCase();

  /// Valores con los que el estudiante puede encontrar el curso.
  List<String> get claves => [
        ?cedula,
        if (email != null) email!.toLowerCase(),
      ];
}
