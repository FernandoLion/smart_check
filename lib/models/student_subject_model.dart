import 'asistencia_resumen.dart';
import 'curso_model.dart';

/// Una materia del estudiante tal como se ve en su tarjeta: horario, docente
/// y asistencia. No lleva notas: el portal del estudiante solo muestra
/// asistencia.
class StudentSubjectModel {
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  final String cursoId;
  final String code;
  final String name;
  final String group;
  final String room;
  final String schedule;
  final String professor;
  final AsistenciaResumen asistencia;

  const StudentSubjectModel({
    required this.cursoId,
    required this.code,
    required this.name,
    required this.group,
    required this.room,
    required this.schedule,
    required this.professor,
    this.asistencia = const AsistenciaResumen(),
  });

  factory StudentSubjectModel.desdeCurso(
    Curso curso, {
    AsistenciaResumen asistencia = const AsistenciaResumen(),
  }) {
    return StudentSubjectModel(
      cursoId: curso.id,
      code: curso.codigo,
      name: curso.nombre,
      group: curso.grupo,
      room: curso.aula,
      schedule: horarioLegible(curso.horarios),
      professor: curso.docenteNombre,
      asistencia: asistencia,
    );
  }

  /// "Lun / Mié • 08:00 - 10:00", o cada bloque aparte si tienen horas
  /// distintas.
  static String horarioLegible(List<Horario> horarios) {
    if (horarios.isEmpty) return 'Sin horario';
    final bloques = [...horarios]..sort((a, b) => a.dia.compareTo(b.dia));
    final mismaFranja = bloques.every(
      (h) => h.inicio == bloques.first.inicio && h.fin == bloques.first.fin,
    );
    if (mismaFranja) {
      final dias = bloques.map((h) => _dias[h.dia - 1]).join(' / ');
      return '$dias • ${bloques.first.inicio} - ${bloques.first.fin}';
    }
    return bloques
        .map((h) => '${_dias[h.dia - 1]} ${h.inicio} - ${h.fin}')
        .join(' / ');
  }

  int get sessionsTotal => asistencia.sesiones;
  int get sessionsAttended => asistencia.asistidas;
  int? get attendancePercent => asistencia.porcentaje;
  NivelAsistencia get status => asistencia.nivel;

  String get sessionsLabel {
    if (asistencia.sesiones == 0) return 'Aún no hay clases registradas';
    final clases = asistencia.sesiones == 1 ? 'clase' : 'clases';
    return '${asistencia.asistidas} de ${asistencia.sesiones} $clases';
  }

  String get statusLabel {
    if (asistencia.porcentaje == null) return 'Sin registro';
    switch (asistencia.nivel) {
      case NivelAsistencia.alDia:
        return 'Al día';
      case NivelAsistencia.atencion:
        return 'Atención';
      case NivelAsistencia.riesgo:
        return 'En riesgo';
    }
  }

  String get absencesBadge {
    if (asistencia.sesiones == 0) return 'Sin clases aún';
    if (asistencia.nivel == NivelAsistencia.riesgo) {
      return 'Por debajo del mínimo';
    }
    final faltas = asistencia.faltasDisponibles;
    if (faltas == 0) return 'Sin faltas disponibles';
    return faltas == 1 ? '1 falta disponible' : '$faltas faltas disponibles';
  }
}
