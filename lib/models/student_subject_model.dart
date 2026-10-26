import 'curso_model.dart';

/// Semáforo de asistencia de una materia.
enum SubjectStatus { safe, warning, critical }

/// Una materia del estudiante tal como se ve en su tarjeta: horario, docente
/// y asistencia. No lleva notas: el portal del estudiante solo muestra
/// asistencia.
class StudentSubjectModel {
  /// Asistencia mínima para no reprobar la materia.
  static const minimoAsistencia = 80;

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  final String cursoId;
  final String code;
  final String name;
  final String group;
  final String room;
  final String schedule;
  final String professor;

  /// Sesiones que ya terminaron y a cuántas asistió.
  final int sessionsTotal;
  final int sessionsAttended;

  const StudentSubjectModel({
    required this.cursoId,
    required this.code,
    required this.name,
    required this.group,
    required this.room,
    required this.schedule,
    required this.professor,
    this.sessionsTotal = 0,
    this.sessionsAttended = 0,
  });

  factory StudentSubjectModel.desdeCurso(
    Curso curso, {
    int sesiones = 0,
    int asistidas = 0,
  }) {
    return StudentSubjectModel(
      cursoId: curso.id,
      code: curso.codigo,
      name: curso.nombre,
      group: curso.grupo,
      room: curso.aula,
      schedule: horarioLegible(curso.horarios),
      professor: curso.docenteNombre,
      sessionsTotal: sesiones,
      sessionsAttended: asistidas,
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

  /// null mientras ninguna sesión haya terminado.
  int? get attendancePercent => sessionsTotal == 0
      ? null
      : (sessionsAttended * 100 / sessionsTotal).round();

  SubjectStatus get status {
    final porcentaje = attendancePercent;
    if (porcentaje == null || porcentaje >= 90) return SubjectStatus.safe;
    if (porcentaje >= minimoAsistencia) return SubjectStatus.warning;
    return SubjectStatus.critical;
  }

  /// Cuántas clases puede faltar todavía sin bajar del mínimo.
  int get faltasDisponibles {
    if (sessionsTotal == 0) return 0;
    final permitidas = (sessionsTotal * (100 - minimoAsistencia) / 100).floor();
    final perdidas = sessionsTotal - sessionsAttended;
    final restantes = permitidas - perdidas;
    return restantes < 0 ? 0 : restantes;
  }

  String get sessionsLabel {
    if (sessionsTotal == 0) return 'Aún no hay clases registradas';
    final clases = sessionsTotal == 1 ? 'clase' : 'clases';
    return '$sessionsAttended de $sessionsTotal $clases';
  }

  String get statusLabel {
    if (attendancePercent == null) return 'Sin registro';
    switch (status) {
      case SubjectStatus.safe:
        return 'Al día';
      case SubjectStatus.warning:
        return 'Atención';
      case SubjectStatus.critical:
        return 'En riesgo';
    }
  }

  String get absencesBadge {
    if (sessionsTotal == 0) return 'Sin clases aún';
    if (status == SubjectStatus.critical) return 'Por debajo del mínimo';
    final faltas = faltasDisponibles;
    if (faltas == 0) return 'Sin faltas disponibles';
    return faltas == 1 ? '1 falta disponible' : '$faltas faltas disponibles';
  }
}
