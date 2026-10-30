import 'package:cloud_firestore/cloud_firestore.dart';

/// Un llamado de asistencia de un curso (`cursos/{id}/sesiones/{id}`).
///
/// [inicio] y [fin] son la ventana del llamado, no la franja entera de la
/// clase: el docente abre el radar y la asistencia solo se puede registrar
/// durante los minutos siguientes, con la sesión abierta.
class Sesion {
  /// El llamado dura esto como máximo: el docente abre el radar, los
  /// estudiantes se verifican y emiten la baliza, y la ventana se cierra.
  /// En pruebas se acorta con `--dart-define=MINUTOS_LLAMADO=1`, para no
  /// esperar diez minutos frente al teléfono; las reglas de Firestore
  /// aceptan ventanas más cortas, nunca más largas.
  static const minutosLlamado =
      int.fromEnvironment('MINUTOS_LLAMADO', defaultValue: 10);

  static const duracionLlamado = Duration(minutes: minutosLlamado);

  final String id;
  final DateTime inicio;
  final DateTime fin;
  final bool abierta;

  /// Hora a la que arranca el bloque de clase del horario. El docente puede
  /// abrir varios llamados dentro del mismo bloque, así que es la franja, y
  /// no el llamado, lo que cuenta como una clase al sacar porcentajes.
  final DateTime? bloqueInicio;

  const Sesion({
    this.id = '',
    required this.inicio,
    required this.fin,
    this.abierta = true,
    this.bloqueInicio,
  });

  /// El llamado que el docente abre en este momento. Nunca pasa del final
  /// del bloque: a una clase a la que le quedan cinco minutos no se le puede
  /// abrir una ventana de diez.
  factory Sesion.llamado({
    required DateTime ahora,
    required DateTime bloqueInicio,
    required DateTime bloqueFin,
  }) {
    final tope = ahora.add(duracionLlamado);
    return Sesion(
      inicio: ahora,
      fin: tope.isAfter(bloqueFin) ? bloqueFin : tope,
      bloqueInicio: bloqueInicio,
    );
  }

  factory Sesion.fromMap(String id, Map<String, dynamic> map) => Sesion(
        id: id,
        inicio: (map['inicio'] as Timestamp).toDate(),
        fin: (map['fin'] as Timestamp).toDate(),
        abierta: map['abierta'] as bool? ?? false,
        bloqueInicio: (map['bloque_inicio'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'abierta': abierta,
        'bloque_inicio': Timestamp.fromDate(bloqueInicio ?? inicio),
      };

  /// La franja de clase a la que pertenece este llamado. Las sesiones
  /// escritas antes de la ventana de diez minutos no traen `bloque_inicio`:
  /// ahí el inicio del llamado era el del bloque, así que sirve igual.
  DateTime get franja => bloqueInicio ?? inicio;

  bool admiteAsistencia(DateTime ahora) =>
      abierta && !ahora.isBefore(inicio) && ahora.isBefore(fin);

  /// Lo que queda de llamado, nunca negativo: lo usan la cuenta atrás de la
  /// pantalla y los temporizadores que cierran la ventana.
  Duration restante(DateTime ahora) {
    final falta = fin.difference(ahora);
    return falta.isNegative ? Duration.zero : falta;
  }

  /// La ventana ya pasó, aunque el documento siga marcado como abierto (pasa
  /// cuando al docente se le muere la app sin cerrar el llamado).
  bool vencida(DateTime ahora) => !ahora.isBefore(fin);

  /// Copia con lo único que cambia en un llamado ya creado: el id que le dio
  /// Firestore y el cierre de la ventana.
  Sesion copyWith({String? id, bool? abierta}) => Sesion(
        id: id ?? this.id,
        inicio: inicio,
        fin: fin,
        abierta: abierta ?? this.abierta,
        bloqueInicio: bloqueInicio,
      );
}

/// Estados posibles de una asistencia.
class EstadoAsistencia {
  static const presente = 'presente';
  static const tarde = 'tarde';
  static const ausente = 'ausente';
}

/// Cómo se registró la asistencia.
class MetodoAsistencia {
  static const ble = 'ble';
  static const manual = 'manual';
}

/// Asistencia de un inscrito a una sesión
/// (`cursos/{id}/sesiones/{id}/asistencias/{claveInscrito}`).
///
/// La guarda el celular del docente al detectar al estudiante por BLE, o el
/// docente a mano en el llamado manual.
class Asistencia {
  final String claveInscrito;
  final String estado;
  final String metodo;
  final DateTime hora;
  final String registradoPor;

  const Asistencia({
    required this.claveInscrito,
    required this.estado,
    required this.metodo,
    required this.hora,
    required this.registradoPor,
  });

  factory Asistencia.fromMap(String clave, Map<String, dynamic> map) =>
      Asistencia(
        claveInscrito: clave,
        estado: map['estado'] as String? ?? EstadoAsistencia.ausente,
        metodo: map['metodo'] as String? ?? MetodoAsistencia.manual,
        hora: (map['hora'] as Timestamp).toDate(),
        registradoPor: map['registrado_por'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'estado': estado,
        'metodo': metodo,
        'hora': Timestamp.fromDate(hora),
        'registrado_por': registradoPor,
      };

  bool get cuentaComoAsistio => estado != EstadoAsistencia.ausente;
}
