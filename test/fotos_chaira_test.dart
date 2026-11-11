import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/services/fotos_chaira.dart';

/// Cada foto se pide a Chairá una sola vez y después se lee del celular.
void main() {
  const url = 'https://chaira.example/Fotos.aspx?mongoid=abc123';
  final foto = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);

  late Directory carpeta;
  late int descargas;
  late Uint8List? respuesta;

  Future<Uint8List?> chaira(String _) async {
    descargas++;
    return respuesta;
  }

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('fotos_chaira_test');
    descargas = 0;
    respuesta = foto;
  });

  tearDown(() {
    if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  });

  test('la primera vez la baja; después ya no', () async {
    final fotos = FotosChaira(chaira, carpeta: carpeta);

    expect(await fotos.foto(url), foto);
    expect(await fotos.foto(url), foto);
    expect(fotos.enMemoria(url), foto);
    expect(descargas, 1);
  });

  test('al abrir la app otra vez la lee del celular, no de Chairá', () async {
    await FotosChaira(chaira, carpeta: carpeta).foto(url);

    final otraVez = FotosChaira(chaira, carpeta: carpeta);
    expect(await otraVez.foto(url), foto);
    expect(descargas, 1);
  });

  test('dos pedidos a la vez hacen una sola descarga', () async {
    final fotos = FotosChaira(chaira, carpeta: carpeta);

    final ambas = await Future.wait([fotos.foto(url), fotos.foto(url)]);

    expect(ambas, [foto, foto]);
    expect(descargas, 1);
  });

  test('si Chairá no la da, no se guarda nada y se vuelve a intentar',
      () async {
    respuesta = null;
    final fotos = FotosChaira(chaira, carpeta: carpeta);

    expect(await fotos.foto(url), isNull);
    respuesta = foto;
    expect(await fotos.foto(url), foto);
    expect(descargas, 2);
  });

  test('olvidarlas las borra de la memoria y del celular', () async {
    final fotos = FotosChaira(chaira, carpeta: carpeta);
    await fotos.foto(url);

    await fotos.olvidarTodo();

    expect(fotos.enMemoria(url), isNull);
    expect(carpeta.existsSync(), isFalse);
    expect(await fotos.foto(url), foto);
    expect(descargas, 2);
  });
}
