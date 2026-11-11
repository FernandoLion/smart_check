import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/calendario_academico.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';
import 'package:smart_check/widgets/calendario_asistencia.dart';
import 'package:smart_check/widgets/calendario_curso.dart';

Curso curso({String periodo = '2026-2', List<Horario>? horarios}) => Curso(
      codigo: 'ISW2',
      nombre: 'Ingeniería de Software II',
      grupo: '1',
      aula: '201',
      periodo: periodo,
      docenteUid: 'uid',
      docenteNombre: 'DOCENTE',
      horarios: horarios ??
          const [Horario(dia: DateTime.thursday, inicio: '06:00', fin: '09:00')],
    );

void main() {
  final semestre = CalendarioAcademico.de('2026-2')!;

  group('semestre 2026-2', () {
    test('va del 18 de agosto al 4 de diciembre, ambos incluidos', () {
      expect(semestre.inicio, DateTime(2026, 8, 18));
      expect(semestre.fin, DateTime(2026, 12, 4));
      expect(semestre.contiene(DateTime(2026, 8, 17, 23)), isFalse);
      expect(semestre.contiene(DateTime(2026, 8, 18, 6)), isTrue);
      expect(semestre.contiene(DateTime(2026, 12, 4, 23)), isTrue);
      expect(semestre.contiene(DateTime(2026, 12, 5)), isFalse);
    });

    test('cuenta las clases según los días del horario', () {
      expect(semestre.clasesSegun([DateTime.thursday]), 16);
      // El 7 de diciembre, que sería el lunes 16, ya no entra.
      expect(semestre.clasesSegun([DateTime.monday]), 15);
      expect(semestre.clasesSegun([DateTime.monday, DateTime.thursday]), 31);
      // Un martes (18 de agosto) y un viernes (4 de diciembre) en los bordes.
      expect(semestre.clasesSegun([DateTime.tuesday]), 16);
      expect(semestre.clasesSegun([DateTime.friday]), 16);
      // Dos bloques el mismo día son dos clases.
      expect(semestre.clasesSegun([DateTime.friday, DateTime.friday]), 32);
    });
  });

  group('un curso', () {
    test('sabe cuántas clases tiene en el semestre', () {
      expect(curso().clasesDelSemestre, 16);
      expect(curso().semestre, isNotNull);
    });

    test('no lo sabe sin horario o en un periodo sin fechas', () {
      expect(curso(horarios: const []).clasesDelSemestre, isNull);
      expect(curso(periodo: '2027-1').clasesDelSemestre, isNull);
      expect(curso(periodo: '2027-1').semestre, isNull);
    });
  });

  group('los calendarios respetan las fechas', () {
    const jueves = [DateTime.thursday];

    test('al estudiante no le muestra clases después del 4 de diciembre', () {
      final diciembre = estadosDelMes(
        mes: DateTime(2026, 12),
        clases: const [],
        diasDeClase: jueves,
        hoy: DateTime(2026, 11, 6),
        semestre: semestre,
      );

      expect(diciembre[3], EstadoDia.proxima);
      expect(diciembre[10], isNull);
    });

    test('al docente no le reclama antes de empezar ni después de acabar', () {
      const horarios = [
        Horario(dia: DateTime.thursday, inicio: '06:00', fin: '09:00'),
      ];
      Map<int, DiaDelCurso> mes(DateTime m, DateTime ahora) => diasDelCurso(
            mes: m,
            sesiones: const <SesionResumen>[],
            horarios: horarios,
            ahora: ahora,
            creadoEn: DateTime(2026, 8, 1),
            semestre: semestre,
          );

      final agosto = mes(DateTime(2026, 8), DateTime(2026, 9, 1));
      expect(agosto[13], isNull); // Antes del 18 de agosto.
      expect(agosto[20]!.estado, EstadoClaseCurso.sinLlamado);

      final diciembre = mes(DateTime(2026, 12), DateTime(2026, 12, 20));
      expect(diciembre[3]!.estado, EstadoClaseCurso.sinLlamado);
      expect(diciembre[10], isNull); // Ya se acabó el semestre.
    });

    test('las flechas no pasan del último mes del semestre', () {
      expect(
        ultimoMesDelCalendario(DateTime(2026, 11, 6), semestre),
        DateTime(2026, 12),
      );
      expect(
        ultimoMesDelCalendario(DateTime(2026, 12, 2), semestre),
        DateTime(2026, 12),
      );
      expect(
        ultimoMesDelCalendario(DateTime(2026, 12, 2), null),
        DateTime(2027, 1),
      );
    });
  });
}
