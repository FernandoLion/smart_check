import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';
import 'package:smart_check/viewmodels/radar_viewmodel.dart';
import 'package:smart_check/widgets/calendario_asistencia.dart';
import 'package:smart_check/widgets/calendario_curso.dart';
import 'package:smart_check/widgets/hoja_clase_extra.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

/// Jueves 19 de noviembre de 2026. La clase es los jueves de 06:00 a 09:00.
final hoy = DateTime(2026, 11, 19, 10);

Curso curso({List<ClaseExtra> extras = const [], List<Horario>? horarios}) =>
    Curso(
      id: 'c1',
      codigo: 'ISW2',
      nombre: 'Ingeniería de Software II',
      grupo: '1',
      aula: '201',
      periodo: '2026-2',
      docenteUid: 'uid-docente',
      docenteNombre: 'DOCENTE',
      horarios: horarios ??
          const [Horario(dia: DateTime.thursday, inicio: '06:00', fin: '09:00')],
      clasesExtra: extras,
    );

/// Una reposición el sábado 21 de 14:00 a 16:00.
final reposicion = ClaseExtra(
  id: 'r1',
  inicio: DateTime(2026, 11, 21, 14),
  fin: DateTime(2026, 11, 21, 16),
  aula: 'Lab 3',
);

void main() {
  group('el modelo', () {
    test('se guarda y se lee igual', () {
      final leido =
          Curso.fromMap('c1', curso(extras: [reposicion]).toMap());

      expect(leido.clasesExtra.single.inicio, reposicion.inicio);
      expect(leido.clasesExtra.single.aula, 'Lab 3');
      expect(Curso.fromMap('c2', const {}).clasesExtra, isEmpty);
    });

    test('la clase extra es una franja de ese día, en orden', () {
      final c = curso(extras: [reposicion]);

      expect(c.franjaEn(DateTime(2026, 11, 21, 15))?.esExtra, isTrue);
      expect(c.franjaEn(DateTime(2026, 11, 21, 16)), isNull);
      // El jueves sigue siendo del horario semanal.
      final jueves = c.franjaEn(DateTime(2026, 11, 19, 7))!;
      expect(jueves.esExtra, isFalse);
      expect(jueves.inicio, DateTime(2026, 11, 19, 6));
    });

    test('suma al total de clases del semestre', () {
      expect(curso().clasesDelSemestre, 16);
      expect(curso(extras: [reposicion]).clasesDelSemestre, 17);
      // Una fuera de las fechas del semestre no cuenta.
      final enero = ClaseExtra(
        id: 'x',
        inicio: DateTime(2027, 1, 20, 8),
        fin: DateTime(2027, 1, 20, 10),
      );
      expect(curso(extras: [enero]).clasesDelSemestre, 16);
    });
  });

  test('el radar se abre en una clase extra, con su franja', () async {
    final cursos = FakeCursoService();
    cursos.inscritosPorCurso['c1'] = {
      '1117000000': const Inscrito(cedula: '1117000000', nombre: 'ANA'),
    };
    final radar = RadarViewModel(
      cursos: cursos,
      ble: FakeBleService(),
      ubicacion: FakeUbicacionService(),
      reloj: () => DateTime(2026, 11, 21, 14, 5),
    );
    addTearDown(radar.dispose);

    expect(await radar.iniciar(curso(extras: [reposicion]), 'uid-docente'),
        isTrue);
    expect(radar.sesion!.franja, reposicion.inicio);

    // Sin la clase extra, ese sábado está fuera del horario.
    final otro = RadarViewModel(
      cursos: cursos,
      ble: FakeBleService(),
      ubicacion: FakeUbicacionService(),
      reloj: () => DateTime(2026, 11, 21, 14, 5),
    );
    addTearDown(otro.dispose);
    expect(await otro.iniciar(curso(), 'uid-docente'), isFalse);
  });

  group('los calendarios', () {
    test('el del docente la espera y luego la reclama si no se dictó', () {
      Map<int, DiaDelCurso> dias(DateTime ahora) => diasDelCurso(
            mes: DateTime(2026, 11),
            sesiones: const <SesionResumen>[],
            horarios: curso().horarios,
            clasesExtra: [reposicion],
            ahora: ahora,
            creadoEn: DateTime(2026, 8, 1),
          );

      expect(dias(hoy)[21]!.estado, EstadoClaseCurso.proxima);
      expect(dias(hoy)[21]!.bloques.single.esExtra, isTrue);
      expect(
        dias(DateTime(2026, 11, 22))[21]!.estado,
        EstadoClaseCurso.sinLlamado,
      );
    });

    test('el del estudiante la muestra como próxima', () {
      final estados = estadosDelMes(
        mes: DateTime(2026, 11),
        clases: const [],
        diasDeClase: const [DateTime.thursday],
        hoy: hoy,
        fechasExtra: [reposicion.inicio],
      );

      expect(estados[21], EstadoDia.proxima);
      expect(estados[22], isNull);
    });
  });

  group('la hoja para programarla', () {
    Future<ClaseExtra?> abrir(
      WidgetTester tester,
      Curso c, {
      DateTime? ahora,
    }) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ClaseExtra? elegida;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  elegida = await showModalBottomSheet<ClaseExtra>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        HojaClaseExtra(curso: c, ahora: ahora ?? hoy),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Programar').last);
      await tester.pumpAndSettle();
      return elegida;
    }

    testWidgets('por defecto propone hoy, una hora después, por dos horas',
        (tester) async {
      final clase = await abrir(tester, curso());

      expect(clase, isNotNull);
      expect(clase!.inicio, DateTime(2026, 11, 19, 11));
      expect(clase.fin, DateTime(2026, 11, 19, 13));
      expect(clase.aula, '201');
    });

    testWidgets('de noche ya no cabe hoy: propone mañana a las 08:00',
        (tester) async {
      final clase =
          await abrir(tester, curso(), ahora: DateTime(2026, 11, 19, 23, 20));

      expect(clase, isNotNull);
      expect(clase!.inicio, DateTime(2026, 11, 20, 8));
      expect(clase.fin, DateTime(2026, 11, 20, 10));
    });

    testWidgets('no deja programarla encima del horario de la clase',
        (tester) async {
      final clase = await abrir(
        tester,
        curso(horarios: const [
          Horario(dia: DateTime.thursday, inicio: '10:30', fin: '12:00'),
        ]),
      );

      expect(clase, isNull);
      expect(find.textContaining('Se cruza con el horario'), findsOneWidget);
    });
  });
}
