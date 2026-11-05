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

  /// A cuántos metros del centro del aula estaba al firmar, y con qué margen
  /// de error del GPS. Null si el curso no tiene geocerca.
  ///
  /// Como el rostro, lo dice la app del estudiante: el servidor no lo puede
  /// comprobar, pero le deja ver al docente si alguien firmó en el límite.
  /// No se guardan sus coordenadas, solo la distancia al aula.
  final int? distanciaAula;
  final int? precisionGps;

  /// Cómo se comprobó su cara antes de firmar: `coincide` (con la que tenía
  /// guardada el celular) o `enrolado` (era la primera vez y se comparó con
  /// la foto de Chairá). Null si no pasó por la verificación facial.
  ///
  /// Lo dice la app del estudiante: el servidor no lo puede comprobar, pero
  /// le sirve al docente para mirar dos veces.
  final String? rostro;

  /// La similitud de esa comparación (de -1 a 1), para calibrar umbrales.
  final double? similitudRostro;

  const Presencia({
    required this.claveInscrito,
    required this.dispositivo,
    required this.vinculadoEn,
    this.distanciaAula,
    this.precisionGps,
    this.creadoEn,
    this.rostro,
    this.similitudRostro,
  });

  /// `creado_en` va como hora del servidor porque la regla exige que sea
  /// `request.time`: con la del celular, adelantar el reloj dejaría firmar
  /// fuera de la ventana.
  Map<String, dynamic> toMap() => {
        'creado_en': FieldValue.serverTimestamp(),
        'dispositivo': dispositivo,
        'vinculado_en': Timestamp.fromDate(vinculadoEn),
        if (distanciaAula != null) 'distancia_aula': distanciaAula,
        if (precisionGps != null) 'precision_gps': precisionGps,
        if (rostro != null) 'rostro': rostro,
        if (similitudRostro != null)
          'similitud_rostro':
              double.parse(similitudRostro!.toStringAsFixed(3)),
      };

  factory Presencia.fromMap(String clave, Map<String, dynamic> map) =>
      Presencia(
        claveInscrito: clave,
        creadoEn: (map['creado_en'] as Timestamp?)?.toDate(),
        dispositivo: map['dispositivo'] as String? ?? '',
        vinculadoEn:
            (map['vinculado_en'] as Timestamp?)?.toDate() ?? DateTime(0),
        distanciaAula: (map['distancia_aula'] as num?)?.round(),
        precisionGps: (map['precision_gps'] as num?)?.round(),
        rostro: map['rostro'] as String?,
        similitudRostro: (map['similitud_rostro'] as num?)?.toDouble(),
      );

  /// Si era la primera vez que verificaba su cara en este celular.
  bool get rostroRecienEnrolado => rostro == 'enrolado';

  /// Si el celular con el que firmó se vinculó hace nada. No prueba nada por
  /// sí solo —cambiar de teléfono es normal—, pero es lo que el docente
  /// querría mirar dos veces.
  bool celularReciente(DateTime ahora) =>
      ahora.difference(vinculadoEn) < const Duration(hours: 24);
}
