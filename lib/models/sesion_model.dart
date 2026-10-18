import 'package:cloud_firestore/cloud_firestore.dart';

/// Una clase concreta de un curso (`cursos/{id}/sesiones/{id}`).
///
/// La asistencia solo se registra mientras la sesión está abierta y la hora
/// actual está entre [inicio] y [fin].
class Sesion {
  final String id;
  final DateTime inicio;
  final DateTime fin;
  final bool abierta;

  const Sesion({
    this.id = '',
    required this.inicio,
    required this.fin,
    this.abierta = true,
  });

  factory Sesion.fromMap(String id, Map<String, dynamic> map) => Sesion(
        id: id,
        inicio: (map['inicio'] as Timestamp).toDate(),
        fin: (map['fin'] as Timestamp).toDate(),
        abierta: map['abierta'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'abierta': abierta,
      };

  bool admiteAsistencia(DateTime ahora) =>
      abierta && !ahora.isBefore(inicio) && ahora.isBefore(fin);
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
