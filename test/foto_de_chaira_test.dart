import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/services/fotos_chaira.dart';
import 'package:smart_check/widgets/foto_de_chaira.dart';

/// La foto del estudiante en su tarjeta, y su dirección en el inscrito.
void main() {
  const url = 'https://chaira.example/Fotos.aspx?mongoid=abc123';
  // Un PNG de 1 x 1.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  late Directory carpeta;
  setUp(() => carpeta = Directory.systemTemp.createTempSync('foto_widget'));
  tearDown(() {
    if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  });

  Widget conFoto(String? url, FotosChaira fotos) => MaterialApp(
        home: Center(
          child: FotoDeChaira(
            url: url,
            diametro: 44,
            fotos: fotos,
            enSuLugar: const Icon(Icons.person),
          ),
        ),
      );

  testWidgets('con la foto guardada, la pinta', (tester) async {
    final fotos = FotosChaira((_) async => png, carpeta: carpeta);
    await tester.runAsync(() => fotos.foto(url));

    await tester.pumpWidget(conFoto(url, fotos));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('sin foto, lo de siempre', (tester) async {
    final fotos = FotosChaira((_) async => null, carpeta: carpeta);

    await tester.pumpWidget(conFoto(null, fotos));

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  group('el inscrito', () {
    test('guarda la dirección de su foto', () {
      const ana = Inscrito(cedula: '1', nombre: 'ANA', fotoUrl: url);
      expect(ana.toMap()['foto_url'], url);
      expect(Inscrito.fromMap(ana.toMap()).fotoUrl, url);
    });

    test('sin foto no manda el campo, para no borrar la que ya tenía', () {
      const ana = Inscrito(cedula: '1', nombre: 'ANA');
      expect(ana.toMap().containsKey('foto_url'), isFalse);
    });
  });
}
