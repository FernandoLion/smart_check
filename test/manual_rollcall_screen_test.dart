import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/viewmodels/radar_viewmodel.dart';
import 'package:smart_check/views/attendance/manual_rollcall_screen.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

/// El llamado manual: derecha presente, izquierda ausente, arriba
/// justificada, y "Deshacer" borra la marca que se guardó.
void main() {
  late FakeCursoService cursos;
  late RadarViewModel radar;

  setUp(() {
    cursos = FakeCursoService();
    cursos.inscritosPorCurso['c1'] = {
      '1117000000': const Inscrito(cedula: '1117000000', nombre: 'ANA PÉREZ'),
      '1117000001': const Inscrito(cedula: '1117000001', nombre: 'BETO RUIZ'),
    };
  });

  /// Abre el radar (que crea el llamado) y la pantalla del llamado manual.
  /// Devuelve a quien muestra primero.
  Future<Inscrito> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    radar = RadarViewModel(
      cursos: cursos,
      ble: FakeBleService(),
      ubicacion: FakeUbicacionService(),
    );
    addTearDown(radar.dispose);
    await tester.runAsync(() => radar.iniciar(cursoEnClase(), 'uid-docente'));
    final primero = radar.lista.firstWhere((f) => !f.registrado).inscrito;
    await tester.pumpWidget(
      MaterialApp(home: ManualRollcallScreen(radar: radar)),
    );
    await tester.pump();
    return primero;
  }

  Asistencia? marcaDe(Inscrito inscrito) {
    final marcas = cursos.asistenciasPorSesion[radar.sesion!.id] ?? [];
    for (final a in marcas) {
      if (a.claveInscrito == inscrito.clave) return a;
    }
    return null;
  }

  /// Arrastra la tarjeta de arriba (la última con ese nombre en el árbol).
  Future<void> arrastrar(
    WidgetTester tester,
    Inscrito inscrito,
    Offset hacia,
  ) async {
    await tester.dragFrom(
      tester.getCenter(find.text(inscrito.nombre).last),
      hacia,
    );
    await tester.pump();
    // La tarjeta sale (260 ms) y la siguiente vuelve al centro (80 ms).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('deslizar hacia arriba justifica la falta', (tester) async {
    final primero = await abrir(tester);

    await arrastrar(tester, primero, const Offset(0, -260));

    expect(marcaDe(primero)?.estado, EstadoAsistencia.justificada);
    expect(marcaDe(primero)?.metodo, MetodoAsistencia.manual);
  });

  testWidgets('deslizar a la derecha es presente y a la izquierda ausente',
      (tester) async {
    final primero = await abrir(tester);
    final segundo = radar.lista
        .firstWhere((f) => f.inscrito.clave != primero.clave)
        .inscrito;

    await arrastrar(tester, primero, const Offset(260, 0));
    expect(marcaDe(primero)?.estado, EstadoAsistencia.presente);

    await arrastrar(tester, segundo, const Offset(-260, 0));
    expect(marcaDe(segundo)?.estado, EstadoAsistencia.ausente);
    // Con el último se cierra el llamado manual.
    await tester.pumpAndSettle();
  });

  testWidgets('un arrastre corto no marca nada', (tester) async {
    final primero = await abrir(tester);

    await arrastrar(tester, primero, const Offset(0, -50));

    expect(marcaDe(primero), isNull);
    expect(find.text(primero.nombre), findsWidgets);
  });

  testWidgets('deshacer vuelve a la tarjeta y borra la marca guardada',
      (tester) async {
    final primero = await abrir(tester);
    await arrastrar(tester, primero, const Offset(0, -260));
    expect(marcaDe(primero), isNotNull);

    await tester.tap(find.text('Deshacer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(marcaDe(primero), isNull);
    expect(
      radar.lista.firstWhere((f) => f.inscrito.clave == primero.clave)
          .registrado,
      isFalse,
    );
    expect(find.text('1 de 2'), findsOneWidget);
  });
}
