import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/sesion_model.dart';

void main() {
  test('sin sesiones terminadas no hay porcentaje que juzgar', () {
    const vacio = AsistenciaResumen();
    expect(vacio.porcentaje, isNull);
    expect(vacio.nivel, NivelAsistencia.alDia);
    expect(vacio.faltas, 0);
  });

  test('redondea el porcentaje', () {
    expect(
      const AsistenciaResumen(sesiones: 3, asistidas: 2).porcentaje,
      67,
    );
  });

  test('el semáforo usa el mínimo del 80%', () {
    expect(const AsistenciaResumen(sesiones: 10, asistidas: 9).nivel,
        NivelAsistencia.alDia);
    expect(const AsistenciaResumen(sesiones: 10, asistidas: 8).nivel,
        NivelAsistencia.atencion);
    expect(const AsistenciaResumen(sesiones: 10, asistidas: 7).nivel,
        NivelAsistencia.riesgo);
  });

  group('faltas justificadas', () {
    Asistencia marca(String estado) => Asistencia(
          claveInscrito: '1117000000',
          estado: estado,
          metodo: MetodoAsistencia.manual,
          hora: DateTime(2026, 10, 1, 8),
          registradoPor: 'uid',
        );

    test('no cuentan como asistencia ni como falla', () {
      final justificada = marca(EstadoAsistencia.justificada);
      expect(justificada.cuentaComoAsistio, isFalse);
      expect(justificada.justificada, isTrue);

      final r = AsistenciaResumen.de([
        ClaseDelEstudiante(DateTime(2026, 10, 1), marca(EstadoAsistencia.presente)),
        ClaseDelEstudiante(DateTime(2026, 10, 2), justificada),
        ClaseDelEstudiante(DateTime(2026, 10, 3), null),
      ]);
      // Se cuentan 2 clases (la justificada no): asistió a 1, faltó a 1.
      expect(r.sesiones, 2);
      expect(r.asistidas, 1);
      expect(r.faltas, 1);
      expect(r.justificadas, 1);
      expect(r.porcentaje, 50);
    });

    test('tampoco cuentan en el total del semestre', () {
      const r = AsistenciaResumen(
        sesiones: 5,
        asistidas: 5,
        justificadas: 2,
        clasesDelSemestre: 32,
      );
      expect(r.clasesContables, 30);
      expect(r.faltasPermitidas, 6);
      expect(r.conClasesDelSemestre(32).justificadas, 2);
    });
  });

  group('con las clases del semestre', () {
    test('el límite no depende de lo dictado hasta hoy', () {
      // Lo que se veía mal: 1 clase dictada decía "0 fallas permitidas".
      const primera = AsistenciaResumen(
        sesiones: 1,
        asistidas: 1,
        clasesDelSemestre: 32,
      );
      expect(primera.faltasPermitidas, 6);
      expect(primera.faltasDisponibles, 6);
      expect(
        const AsistenciaResumen(clasesDelSemestre: 32).faltasDisponibles,
        6,
      );
    });

    test('el semáforo se pone rojo justo al pasarse del límite', () {
      AsistenciaResumen conFaltas(int n) => AsistenciaResumen(
            sesiones: 10,
            asistidas: 10 - n,
            clasesDelSemestre: 32,
          );

      // Faltar a la mitad de lo dictado no reprueba si aún hay margen.
      expect(conFaltas(3).nivel, NivelAsistencia.alDia);
      expect(conFaltas(4).nivel, NivelAsistencia.atencion);
      expect(conFaltas(6).nivel, NivelAsistencia.atencion);
      expect(conFaltas(6).faltasDisponibles, 0);
      expect(conFaltas(7).nivel, NivelAsistencia.riesgo);
    });

    test('rojo y límite de fallas coinciden con cualquier total', () {
      for (var total = 1; total <= 80; total++) {
        for (var faltas = 0; faltas <= total; faltas++) {
          final r = AsistenciaResumen(
            sesiones: total,
            asistidas: total - faltas,
            clasesDelSemestre: total,
          );
          expect(
            r.nivel == NivelAsistencia.riesgo,
            r.faltas > r.faltasPermitidas,
            reason: '$faltas faltas de $total clases',
          );
        }
      }
    });

    test('sin el dato no dice conocer el semestre', () {
      const sinDato = AsistenciaResumen(sesiones: 4, asistidas: 4);
      expect(sinDato.conoceElSemestre, isFalse);
      expect(sinDato.conClasesDelSemestre(16).conoceElSemestre, isTrue);
      expect(sinDato.conClasesDelSemestre(null).conoceElSemestre, isFalse);
      expect(sinDato.conClasesDelSemestre(0).conoceElSemestre, isFalse);
    });
  });

  test('cuenta las faltas permitidas y las que quedan', () {
    // De 10 clases puede faltar a 2; ya faltó a 1.
    const una = AsistenciaResumen(sesiones: 10, asistidas: 9);
    expect(una.faltas, 1);
    expect(una.faltasPermitidas, 2);
    expect(una.faltasDisponibles, 1);

    expect(
      const AsistenciaResumen(sesiones: 10, asistidas: 8).faltasDisponibles,
      0,
    );
    // Ya pasado del límite, no quedan negativas.
    expect(
      const AsistenciaResumen(sesiones: 10, asistidas: 5).faltasDisponibles,
      0,
    );
  });
}
