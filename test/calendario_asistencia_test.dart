import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/widgets/calendario_asistencia.dart';

Asistencia marca(DateTime hora, {String estado = EstadoAsistencia.presente}) =>
    Asistencia(
      claveInscrito: '1117000000',
      estado: estado,
      metodo: MetodoAsistencia.ble,
      hora: hora,
      registradoPor: 'uid-docente',
    );

void main() {
  // Jueves 5 de noviembre de 2026; la materia es los lunes y jueves.
  final hoy = DateTime(2026, 11, 5, 10);
  const lunesYJueves = [DateTime.monday, DateTime.thursday];

  group('estadosDelMes', () {
    test('pinta cada clase dictada según lo que pasó', () {
      final clases = [
        ClaseDelEstudiante(
          DateTime(2026, 11, 2, 6),
          marca(DateTime(2026, 11, 2, 6, 5)),
        ),
        ClaseDelEstudiante(
          DateTime(2026, 11, 5, 6),
          marca(DateTime(2026, 11, 5, 6, 40), estado: EstadoAsistencia.tarde),
        ),
        ClaseDelEstudiante(DateTime(2026, 10, 29, 6), null),
      ];

      final noviembre = estadosDelMes(
        mes: DateTime(2026, 11),
        clases: clases,
        diasDeClase: lunesYJueves,
        hoy: hoy,
      );
      expect(noviembre[2], EstadoDia.asistio);
      expect(noviembre[5], EstadoDia.parcial); // Llegó tarde.
      // De aquí en adelante, los lunes y jueves son próximas clases.
      expect(noviembre[9], EstadoDia.proxima);
      expect(noviembre[12], EstadoDia.proxima);
      expect(noviembre[10], isNull); // Martes: no hay clase.

      final octubre = estadosDelMes(
        mes: DateTime(2026, 10),
        clases: clases,
        diasDeClase: lunesYJueves,
        hoy: hoy,
      );
      expect(octubre[29], EstadoDia.falto);
      // Un lunes pasado sin llamado no se pinta: esa clase no se dictó.
      expect(octubre[26], isNull);
    });

    test('la falta justificada se pinta aparte y no cuenta', () {
      final estados = estadosDelMes(
        mes: DateTime(2026, 11),
        clases: [
          ClaseDelEstudiante(
            DateTime(2026, 11, 2, 6),
            marca(DateTime(2026, 11, 2, 7), estado: EstadoAsistencia.justificada),
          ),
          // Asistió a una y la otra se la justificaron: el día cuenta como
          // asistido.
          ClaseDelEstudiante(
            DateTime(2026, 11, 3, 6),
            marca(DateTime(2026, 11, 3, 6, 5)),
          ),
          ClaseDelEstudiante(
            DateTime(2026, 11, 3, 10),
            marca(DateTime(2026, 11, 3, 11), estado: EstadoAsistencia.justificada),
          ),
        ],
        diasDeClase: const [],
        hoy: hoy,
      );
      expect(estados[2], EstadoDia.justificada);
      expect(estados[3], EstadoDia.asistio);
    });

    test('dos clases el mismo día: asistió a una y faltó a otra', () {
      final estados = estadosDelMes(
        mes: DateTime(2026, 11),
        clases: [
          ClaseDelEstudiante(
            DateTime(2026, 11, 2, 6),
            marca(DateTime(2026, 11, 2, 6, 5)),
          ),
          ClaseDelEstudiante(DateTime(2026, 11, 2, 10), null),
        ],
        diasDeClase: const [],
        hoy: hoy,
      );
      expect(estados[2], EstadoDia.parcial);
    });
  });

  testWidgets('se navega de mes y muestra el detalle de un día', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarioAsistencia(
              clases: [
                ClaseDelEstudiante(DateTime(2026, 10, 29, 6), null),
                ClaseDelEstudiante(
                  DateTime(2026, 11, 2, 6),
                  marca(DateTime(2026, 11, 2, 6, 5)),
                ),
              ],
              diasDeClase: lunesYJueves,
              hoy: hoy,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.text('En noviembre: asistió a 1 de 1 clase.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dia-2')));
    await tester.pump();
    expect(find.text('Lunes 2 de noviembre'), findsOneWidget);
    expect(
      find.text('Clase de las 06:00: asistió (radar BLE, 06:05)'),
      findsOneWidget,
    );

    // Hacia atrás llega hasta el mes de la primera clase, y no más.
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pump();
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(
      find.text('En octubre: asistió a 0 de 1 clase, faltó a 1.'),
      findsOneWidget,
    );
    final anterior = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(anterior.onPressed, isNull);
  });
}
