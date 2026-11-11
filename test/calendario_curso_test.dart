import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';
import 'package:smart_check/widgets/calendario_curso.dart';

/// Una clase ya dictada a las 06:00 de [dia].
SesionResumen clase(DateTime dia, int asistieron, int inscritos) {
  final inicio = DateTime(dia.year, dia.month, dia.day, 6);
  return SesionResumen(
    Sesion(
      id: 'sesion-${dia.month}-${dia.day}',
      inicio: inicio.add(const Duration(minutes: 5)),
      fin: inicio.add(const Duration(minutes: 15)),
      bloqueInicio: inicio,
      abierta: false,
    ),
    asistieron,
    inscritos,
  );
}

void main() {
  // Jueves 19 de noviembre de 2026, a las 10; la clase es lunes y jueves de
  // 06:00 a 09:00, y el curso se creó el martes 3.
  final ahora = DateTime(2026, 11, 19, 10);
  final creado = DateTime(2026, 11, 3, 12);
  const horarios = [
    Horario(dia: DateTime.monday, inicio: '06:00', fin: '09:00'),
    Horario(dia: DateTime.thursday, inicio: '06:00', fin: '09:00'),
  ];

  Map<int, DiaDelCurso> dias(
    List<SesionResumen> sesiones, {
    DateTime? creadoEn,
    DateTime? momento,
    bool archivado = false,
    DateTime? mes,
  }) =>
      diasDelCurso(
        mes: mes ?? DateTime(2026, 11),
        sesiones: sesiones,
        horarios: horarios,
        ahora: momento ?? ahora,
        creadoEn: creadoEn,
        archivado: archivado,
      );

  group('diasDelCurso', () {
    test('el color sale del porcentaje del grupo', () {
      final d = dias([
        clase(DateTime(2026, 11, 5), 9, 10),
        clase(DateTime(2026, 11, 9), 8, 10),
        clase(DateTime(2026, 11, 12), 7, 10),
      ], creadoEn: creado);

      expect(d[5]!.estado, EstadoClaseCurso.alta);
      expect(d[5]!.porcentaje, 90);
      expect(d[9]!.estado, EstadoClaseCurso.media);
      expect(d[12]!.estado, EstadoClaseCurso.baja);
    });

    test('marca los días que tocaba clase y no se abrió el radar', () {
      final d = dias([clase(DateTime(2026, 11, 5), 9, 10)], creadoEn: creado);

      expect(d[9]!.estado, EstadoClaseCurso.sinLlamado);
      expect(d[12]!.estado, EstadoClaseCurso.sinLlamado);
      expect(d[16]!.estado, EstadoClaseCurso.sinLlamado);
      // Martes: no toca clase.
      expect(d[10], isNull);
    });

    test('no reclama las clases de antes de crear el curso', () {
      final d = dias(const [], creadoEn: creado);

      // Lunes 2: el curso todavía no existía.
      expect(d[2], isNull);
      expect(d[5]!.estado, EstadoClaseCurso.sinLlamado);
    });

    test('tampoco la de un bloque que ya había terminado al crearlo', () {
      final d = dias(
        const [],
        // Jueves 5 a mediodía: esa clase ya había pasado.
        creadoEn: DateTime(2026, 11, 5, 12),
      );

      expect(d[5], isNull);
      expect(d[9]!.estado, EstadoClaseCurso.sinLlamado);
    });

    test('hoy no es "sin llamado" hasta que termine el bloque', () {
      final enClase = dias(
        const [],
        creadoEn: creado,
        momento: DateTime(2026, 11, 19, 8),
      );
      expect(enClase[19]!.estado, EstadoClaseCurso.proxima);

      // A las 10 ya terminó y nadie abrió el radar.
      expect(dias(const [], creadoEn: creado)[19]!.estado,
          EstadoClaseCurso.sinLlamado);
    });

    test('lo que viene son próximas clases', () {
      final d = dias(const [], creadoEn: creado);

      expect(d[23]!.estado, EstadoClaseCurso.proxima);
      expect(d[26]!.estado, EstadoClaseCurso.proxima);
    });

    test('sin fecha de creación cuenta desde la primera clase dictada', () {
      final d = dias([clase(DateTime(2026, 11, 9), 9, 10)]);

      expect(d[5], isNull);
      expect(d[12]!.estado, EstadoClaseCurso.sinLlamado);
    });

    test('sin fecha ni clases no acusa nada', () {
      expect(
        dias(const []).values.map((d) => d.estado),
        everyElement(EstadoClaseCurso.proxima),
      );
    });

    test('de un curso archivado no espera nada tras su última clase', () {
      final d = dias(
        [clase(DateTime(2026, 11, 5), 9, 10)],
        creadoEn: creado,
        archivado: true,
      );

      expect(d[5]!.estado, EstadoClaseCurso.alta);
      expect(d[9], isNull);
      expect(d[23], isNull);
    });

    test('una clase dictada fuera del horario también aparece', () {
      final martes = DateTime(2026, 11, 10);
      expect(
        dias([clase(martes, 10, 10)], creadoEn: creado)[10]!.estado,
        EstadoClaseCurso.alta,
      );
    });
  });

  testWidgets('muestra el % y abre la clase al tocarla', (tester) async {
    // De celular y alto, para que el detalle del día quede a la vista.
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SesionResumen? abierta;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarioDelCurso(
              sesiones: [clase(DateTime(2026, 11, 5), 8, 10)],
              horarios: horarios,
              ahora: ahora,
              creadoEn: creado,
              alAbrirClase: (c) => abierta = c,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Noviembre 2026'), findsOneWidget);
    // El porcentaje del grupo se ve al tocar el día.
    expect(find.bySemanticsLabel(RegExp('^5, clase con 80 por ciento')),
        findsOneWidget);
    // Lunes 9, jueves 12, lunes 16 y hoy, jueves 19.
    expect(
      find.text(
        'En noviembre: 1 clase dictada, 80% de asistencia, '
        '4 días sin llamado.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('dia-5')));
    await tester.pump();
    expect(find.text('Jueves 5 de noviembre'), findsOneWidget);
    await tester.tap(find.text('Clase de las 06:00: 8 de 10 (80%)'));
    expect(abierta?.asistieron, 8);

    await tester.tap(find.byKey(const ValueKey('dia-9')));
    await tester.pump();
    expect(
      find.text('Tocaba clase de 06:00 a 09:00 y no se abrió el radar.'),
      findsOneWidget,
    );

    // Atrás no pasa del mes en que se creó el curso.
    final anterior = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(anterior.onPressed, isNull);
  });
}
