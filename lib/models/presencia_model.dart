import 'package:cloud_firestore/cloud_firestore.dart';

/// La firma del estudiante
/// (`cursos/{id}/sesiones/{id}/presencias/{claveInscrito}`).
///
/// Es la otra llave de la asistencia. El celular del estudiante no escribía
/// nada en Firestore —solo emitía BLE—, así que todo lo que comprobaba su
/// lado lo comprobaba su propia app. Esto es lo único que el servidor sabe
/// de ese lado: que una cuenta concreta, desde el celular que tiene atado,
/// dijo "estoy aquí" dentro de la ventana del llamado.
///
/// Las reglas exigen que exista para aceptar una asistencia por BLE. El
/// llamado manual del docente se la salta, a propósito: es su corrección.
class Presencia {
  /// La misma clave con la que el docente lo inscribió (cédula o correo),
  /// para que las reglas puedan cruzarla con la asistencia.
  final String claveInscrito;

  /// La hora del servidor. Null mientras no vuelve de Firestore.
  final DateTime? creadoEn;

  /// El celular desde el que se firmó. La regla comprueba que sea el que la
  /// cuenta tiene atado.
  final String dispositivo;

  /// Desde cuándo está atado ese celular. Viaja aquí porque el docente no
  /// puede leer el perfil del estudiante, y es su única forma de ver un
  /// celular recién vinculado. La regla lo compara con el perfil, así que
  /// no se puede falsear.
  final DateTime vinculadoEn;

  /// Con qué comprobó el teléfono a su dueño: `biometrica`, `credencial` o
  /// `no_disponible`.
  final String biometria;

  const Presencia({
    required this.claveInscrito,
    required this.dispositivo,
    required this.vinculadoEn,
    required this.biometria,
    this.creadoEn,
  });

  /// `creado_en` va como hora del servidor porque la regla exige que sea
  /// `request.time`: con la del celular, adelantar el reloj dejaría firmar
  /// fuera de la ventana.
  Map<String, dynamic> toMap() => {
        'creado_en': FieldValue.serverTimestamp(),
        'dispositivo': dispositivo,
        'vinculado_en': Timestamp.fromDate(vinculadoEn),
        'biometria': biometria,
      };

  factory Presencia.fromMap(String clave, Map<String, dynamic> map) =>
      Presencia(
        claveInscrito: clave,
        creadoEn: (map['creado_en'] as Timestamp?)?.toDate(),
        dispositivo: map['dispositivo'] as String? ?? '',
        vinculadoEn:
            (map['vinculado_en'] as Timestamp?)?.toDate() ?? DateTime(0),
        biometria: map['biometria'] as String? ?? 'no_disponible',
      );

  /// Si el celular con el que firmó se vinculó hace nada. No prueba nada por
  /// sí solo —cambiar de teléfono es normal—, pero es lo que el docente
  /// querría mirar dos veces.
  bool celularReciente(DateTime ahora) =>
      ahora.difference(vinculadoEn) < const Duration(hours: 24);

  /// Si el teléfono no tenía con qué comprobar a su dueño.
  bool get sinBiometria => biometria == 'no_disponible';
}
