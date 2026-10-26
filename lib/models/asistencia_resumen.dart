/// Semáforo de asistencia, igual en el portal del estudiante y en el panel
/// docente.
enum NivelAsistencia { alDia, atencion, riesgo }

/// Cuántas sesiones ya terminaron y a cuántas asistió alguien, con las reglas
/// de asistencia de la universidad. Es la única fuente de esos límites.
class AsistenciaResumen {
  /// Asistencia mínima para no reprobar la materia.
  static const minimo = 80;

  final int sesiones;
  final int asistidas;

  const AsistenciaResumen({this.sesiones = 0, this.asistidas = 0});

  /// null mientras ninguna sesión haya terminado: aún no hay nada que juzgar.
  int? get porcentaje =>
      sesiones == 0 ? null : (asistidas * 100 / sesiones).round();

  NivelAsistencia get nivel {
    final p = porcentaje;
    if (p == null || p >= 90) return NivelAsistencia.alDia;
    if (p >= minimo) return NivelAsistencia.atencion;
    return NivelAsistencia.riesgo;
  }

  int get faltas => sesiones - asistidas;

  /// Faltas que permite el mínimo sobre el total de sesiones dictadas.
  int get faltasPermitidas => (sesiones * (100 - minimo) / 100).floor();

  /// Las que todavía puede darse sin bajar del mínimo.
  int get faltasDisponibles {
    final restantes = faltasPermitidas - faltas;
    return restantes < 0 ? 0 : restantes;
  }
}
