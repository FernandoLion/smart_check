import 'sesion_model.dart';

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

  /// El resumen de las clases que ya terminaron, una por franja.
  factory AsistenciaResumen.de(List<ClaseDelEstudiante> clases) =>
      AsistenciaResumen(
        sesiones: clases.length,
        asistidas: clases.where((c) => c.asistio).length,
      );

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

/// Una clase que ya terminó, vista por el estudiante: si asistió y con qué
/// marca. Una clase es una franja del horario, aunque el docente haya
/// abierto el radar más de una vez en ella.
class ClaseDelEstudiante {
  final DateTime franja;

  /// La marca que decide su estado, o null si nadie lo marcó (faltó).
  final Asistencia? marca;

  const ClaseDelEstudiante(this.franja, this.marca);

  bool get asistio => marca?.cuentaComoAsistio ?? false;
}
