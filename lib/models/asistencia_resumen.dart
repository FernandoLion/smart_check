import 'dart:math';

import 'sesion_model.dart';

/// Semáforo de asistencia, igual en el portal del estudiante y en el panel
/// docente.
enum NivelAsistencia { alDia, atencion, riesgo }

/// Cuántas sesiones ya terminaron y a cuántas asistió alguien, con las reglas
/// de asistencia de la universidad. Es la única fuente de esos límites.
class AsistenciaResumen {
  /// Asistencia mínima para no reprobar la materia.
  static const minimo = 80;

  /// Las clases que se le cuentan: las ya dictadas, sin las justificadas.
  final int sesiones;
  final int asistidas;

  /// Faltas justificadas por el docente. No están en [sesiones]: esas clases
  /// no se le cuentan, ni como falla ni como asistencia.
  final int justificadas;

  /// Las clases que tendrá el curso en todo el semestre, según su horario y
  /// el calendario académico. Null si no se sabe. De aquí sale el límite de
  /// fallas: se cuenta sobre el semestre, no sobre lo dictado hasta hoy.
  final int? clasesDelSemestre;

  const AsistenciaResumen({
    this.sesiones = 0,
    this.asistidas = 0,
    this.justificadas = 0,
    this.clasesDelSemestre,
  });

  AsistenciaResumen conClasesDelSemestre(int? total) => AsistenciaResumen(
        sesiones: sesiones,
        asistidas: asistidas,
        justificadas: justificadas,
        clasesDelSemestre: total,
      );

  /// Las clases del semestre que se le cuentan: las justificadas no. Null
  /// si no se conoce el semestre.
  int? get clasesContables {
    final total = clasesDelSemestre;
    return total == null ? null : max(0, total - justificadas);
  }

  /// Si se sabe cuántas clases tiene el semestre. Sin eso no hay un límite
  /// de fallas que mostrar.
  bool get conoceElSemestre => (clasesContables ?? 0) > 0;

  /// El resumen de las clases que ya terminaron, una por franja. Las
  /// justificadas se apartan: no cuentan ni a favor ni en contra.
  factory AsistenciaResumen.de(List<ClaseDelEstudiante> clases) =>
      AsistenciaResumen(
        sesiones: clases.where((c) => !c.justificada).length,
        asistidas: clases.where((c) => c.asistio).length,
        justificadas: clases.where((c) => c.justificada).length,
      );

  /// null mientras ninguna sesión haya terminado: aún no hay nada que juzgar.
  int? get porcentaje =>
      sesiones == 0 ? null : (asistidas * 100 / sesiones).round();

  /// El semáforo. Conociendo el semestre, sale del porcentaje que aún puede
  /// alcanzar al final: así el rojo llega justo cuando se pasa del límite de
  /// fallas, y no por faltar a una de las dos primeras clases.
  NivelAsistencia get nivel {
    if (!conoceElSemestre) return nivelDe(porcentaje);
    final total = clasesContables!;
    return nivelDe(((total - faltas) * 100 / total).floor());
  }

  /// El nivel de un porcentaje; sin dato no hay nada que juzgar.
  static NivelAsistencia nivelDe(int? porcentaje) {
    if (porcentaje == null || porcentaje >= 90) return NivelAsistencia.alDia;
    if (porcentaje >= minimo) return NivelAsistencia.atencion;
    return NivelAsistencia.riesgo;
  }

  int get faltas => sesiones - asistidas;

  /// Faltas que permite el mínimo sobre las clases del semestre. Si no se
  /// conoce, sobre las dictadas: es solo una cota, y las pantallas no la
  /// muestran (ver [conoceElSemestre]).
  int get faltasPermitidas =>
      ((clasesContables ?? sesiones) * (100 - minimo) / 100).floor();

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

  /// El docente le justificó la falta: esta clase no se le cuenta.
  bool get justificada => marca?.justificada ?? false;
}
