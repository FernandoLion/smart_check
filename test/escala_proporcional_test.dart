import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/utils/escala_proporcional.dart';

void main() {
  group('factorDeEscala', () {
    test('en cualquier celular es 1: nada cambia', () {
      expect(factorDeEscala(const Size(320, 640)), 1.0);
      expect(factorDeEscala(const Size(393, 852)), 1.0);
      expect(factorDeEscala(const Size(430, 932)), 1.0);
    });

    test('en una tablet crece en proporción al lado corto', () {
      expect(factorDeEscala(const Size(600, 960)), closeTo(600 / 430, 1e-9));
      // Acostada cuenta igual: manda el lado corto.
      expect(factorDeEscala(const Size(960, 600)), closeTo(600 / 430, 1e-9));
    });

    test('tiene un tope para las tablets grandes', () {
      expect(factorDeEscala(const Size(800, 1280)), escalaMaximaDePantalla);
      expect(factorDeEscala(const Size(1200, 1920)), escalaMaximaDePantalla);
    });
  });

  testWidgets('en una tablet la app se arma al tamaño lógico y se agranda',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size visto;
    late double letra;
    await tester.pumpWidget(
      MaterialApp(
        builder: adaptarAPantalla,
        home: Builder(
          builder: (context) {
            visto = MediaQuery.sizeOf(context);
            letra = MediaQuery.textScalerOf(context).scale(10);
            return const Scaffold(body: Text('hola'));
          },
        ),
      ),
    );

    // Las pantallas ven un celular de 444 dp de ancho...
    expect(visto.width, closeTo(800 / escalaMaximaDePantalla, 0.01));
    expect(letra, 10);
    // ...y lo que dibujan ocupa la tablet entera, agrandado.
    final caja = tester.getSize(find.byType(Scaffold));
    expect(tester.getSize(find.byType(Scaffold)).width, closeTo(visto.width, 0.01));
    final enPantalla = tester.getRect(find.byType(Scaffold));
    expect(enPantalla.width, closeTo(800, 0.5));
    expect(caja.height, closeTo(1280 / escalaMaximaDePantalla, 0.01));
  });

  testWidgets('en un celular no toca nada salvo el tope de la letra',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    late Size visto;
    late double letra;
    await tester.pumpWidget(
      MaterialApp(
        builder: adaptarAPantalla,
        home: Builder(
          builder: (context) {
            visto = MediaQuery.sizeOf(context);
            letra = MediaQuery.textScalerOf(context).scale(10);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(visto, const Size(390, 844));
    expect(letra, 13); // 2.0 recortado a 1.3.
  });
}
