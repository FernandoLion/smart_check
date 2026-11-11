import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/student_subject_model.dart';

StudentSubjectModel materia({
  int sesiones = 0,
  int asistidas = 0,
  int? semestre,
}) =>
    StudentSubjectModel(
      cursoId: 'c1',
      code: 'SIS-402',
      name: 'Arquitectura de Software',
      group: '302-B',
      room: 'Aula 204',
      schedule: 'Mar / Jue • 08:00 - 10:00',
      professor: 'ANA MARÍA PÉREZ GÓMEZ',
      asistencia: AsistenciaResumen(
        sesiones: sesiones,
        asistidas: asistidas,
        clasesDelSemestre: semestre,
      ),
    );

void main() {
  group('horarioLegible', () {
    test('junta los días cuando comparten la franja', () {
      expect(
        StudentSubjectModel.horarioLegible(const [
          Horario(dia: DateTime.thursday, inicio: '08:00', fin: '10:00'),
          Horario(dia: DateTime.tuesday, inicio: '08:00', fin: '10:00'),
        ]),
        'Mar / Jue • 08:00 - 10:00',
      );
    });

    test('separa los bloques con horas distintas', () {
      expect(
        StudentSubjectModel.horarioLegible(const [
          Horario(dia: DateTime.monday, inicio: '08:00', fin: '10:00'),
          Horario(dia: DateTime.wednesday, inicio: '14:00', fin: '16:00'),
        ]),
        'Lun 08:00 - 10:00 / Mié 14:00 - 16:00',
      );
    });

    test('sin bloques lo dice', () {
      expect(StudentSubjectModel.horarioLegible(const []), 'Sin horario');
    });
  });

  group('textos de la tarjeta', () {
    test('sin clases registradas no inventa nada', () {
      final sinClases = materia();
      expect(sinClases.attendancePercent, isNull);
      expect(sinClases.statusLabel, 'Sin registro');
      expect(sinClases.sessionsLabel, 'Aún no hay clases registradas');
      expect(sinClases.absencesBadge, 'Sin clases aún');
    });

    test('usa el singular con una sola clase', () {
      expect(materia(sesiones: 1, asistidas: 1).sessionsLabel, '1 de 1 clase');
      expect(materia(sesiones: 2, asistidas: 1).sessionsLabel, '1 de 2 clases');
    });

    test('nombra el nivel de asistencia', () {
      expect(materia(sesiones: 10, asistidas: 10).statusLabel, 'Al día');
      expect(materia(sesiones: 10, asistidas: 8).statusLabel, 'Atención');
      expect(materia(sesiones: 10, asistidas: 5).statusLabel, 'En riesgo');
    });

    test('avisa cuando ya está por debajo del mínimo', () {
      // Con 10 clases en el semestre se puede faltar a 2.
      expect(materia(sesiones: 10, asistidas: 5, semestre: 10).absencesBadge,
          'Por debajo del mínimo');
      expect(materia(sesiones: 10, asistidas: 8, semestre: 10).absencesBadge,
          'Sin faltas disponibles');
      expect(materia(sesiones: 10, asistidas: 9, semestre: 10).absencesBadge,
          '1 falta disponible');
      // Lo que importa es el semestre, no lo dictado hasta hoy: con 1 clase
      // de 32 todavía quedan las 6 (antes decía que ninguna).
      expect(materia(sesiones: 1, asistidas: 1, semestre: 32).absencesBadge,
          '6 faltas disponibles');
      expect(materia(semestre: 32).absencesBadge, '6 faltas disponibles');
    });
  });

  test('se arma desde el curso', () {
    const curso = Curso(
      id: 'c1',
      codigo: 'SIS-402',
      nombre: 'Arquitectura de Software',
      grupo: '302-B',
      aula: 'Aula 204',
      periodo: '2026-2',
      docenteUid: 'uid-docente',
      docenteNombre: 'ANA MARÍA PÉREZ GÓMEZ',
      horarios: [Horario(dia: DateTime.tuesday, inicio: '08:00', fin: '10:00')],
    );

    final materia = StudentSubjectModel.desdeCurso(
      curso,
      asistencia: const AsistenciaResumen(sesiones: 4, asistidas: 3),
    );

    expect(materia.cursoId, 'c1');
    expect(materia.professor, 'ANA MARÍA PÉREZ GÓMEZ');
    expect(materia.schedule, 'Mar • 08:00 - 10:00');
    expect(materia.attendancePercent, 75);
    // Una falta de las 16 clases del semestre no pone en riesgo a nadie,
    // aunque hasta hoy lleve 75 %.
    expect(materia.asistencia.clasesDelSemestre, 16);
    expect(materia.status, NivelAsistencia.alDia);
    expect(materia.semestre, isNotNull);
  });

  test('sin fechas del semestre no inventa cuántas faltas quedan', () {
    final sinFechas = materia(sesiones: 4, asistidas: 3);

    expect(sinFechas.absencesBadge, '1 falta');
    expect(materia(sesiones: 1, asistidas: 1).absencesBadge, '0 faltas');
  });
}
