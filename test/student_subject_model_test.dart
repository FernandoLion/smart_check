import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/student_subject_model.dart';

StudentSubjectModel materia({int sesiones = 0, int asistidas = 0}) =>
    StudentSubjectModel(
      cursoId: 'c1',
      code: 'SIS-402',
      name: 'Arquitectura de Software',
      group: '302-B',
      room: 'Aula 204',
      schedule: 'Mar / Jue • 08:00 - 10:00',
      professor: 'ANA MARÍA PÉREZ GÓMEZ',
      asistencia:
          AsistenciaResumen(sesiones: sesiones, asistidas: asistidas),
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
      expect(materia(sesiones: 10, asistidas: 5).absencesBadge,
          'Por debajo del mínimo');
      expect(materia(sesiones: 10, asistidas: 8).absencesBadge,
          'Sin faltas disponibles');
      expect(materia(sesiones: 20, asistidas: 19).absencesBadge,
          '3 faltas disponibles');
      expect(materia(sesiones: 10, asistidas: 9).absencesBadge,
          '1 falta disponible');
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
    expect(materia.status, NivelAsistencia.riesgo);
  });
}
