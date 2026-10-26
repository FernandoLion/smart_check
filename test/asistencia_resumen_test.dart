import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';

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
