import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'chaira_service.dart';

/// Las fotos de Chairá que ya se bajaron, guardadas en el celular, en la
/// carpeta privada de la app. Cada foto se pide a Chairá una sola vez: no en
/// cada inicio de sesión ni cada vez que se abre la lista de un curso.
///
/// No se suben a la base de datos: son datos personales, y otra copia en la
/// nube sería una más que proteger (Ley 1581 de 2012). Al cerrar sesión se
/// borran del celular.
class FotosChaira {
  final Future<Uint8List?> Function(String url) _descargar;
  final Directory _carpeta;

  /// [_descargar] la baja de Chairá cuando no está en el celular.
  FotosChaira(this._descargar, {Directory? carpeta})
      : _carpeta = carpeta ?? carpetaPorDefecto;

  /// La que usan las pantallas. Se crea al usarse por primera vez.
  static FotosChaira get compartida =>
      _compartida ??= FotosChaira(ChairaService().descargarFoto);
  static FotosChaira? _compartida;

  /// La carpeta temporal de la app es privada: otra app no la lee, y si el
  /// sistema necesita espacio la puede vaciar (la foto se vuelve a bajar).
  static Directory get carpetaPorDefecto =>
      Directory('${Directory.systemTemp.path}/fotos_chaira');

  final _enMemoria = <String, Uint8List>{};
  final _enCamino = <String, Future<Uint8List?>>{};

  /// La que ya está en memoria, sin esperar a nada (para pintar de una vez).
  Uint8List? enMemoria(String url) => _enMemoria[url];

  /// La foto de [url]: de la memoria, del celular o, si no está, de Chairá.
  /// null si Chairá no la da. Dos pedidos de la misma foto a la vez hacen
  /// una sola descarga.
  Future<Uint8List?> foto(String url) {
    final lista = _enMemoria[url];
    if (lista != null) return Future.value(lista);
    // Con llaves: `remove` devuelve este mismo futuro, y si se devolviera,
    // whenComplete se quedaría esperándose a sí mismo.
    return _enCamino[url] ??= _buscar(url).whenComplete(() {
      _enCamino.remove(url);
    });
  }

  Future<Uint8List?> _buscar(String url) async {
    final archivo = File('${_carpeta.path}/${_nombre(url)}');
    try {
      if (await archivo.exists()) {
        final guardada = await archivo.readAsBytes();
        if (guardada.isNotEmpty) return _enMemoria[url] = guardada;
      }
    } on FileSystemException {
      // Sin el archivo, se baja otra vez.
    }
    final bajada = await _descargar(url);
    if (bajada == null || bajada.isEmpty) return null;
    _enMemoria[url] = bajada;
    try {
      await _carpeta.create(recursive: true);
      await archivo.writeAsBytes(bajada, flush: true);
    } on FileSystemException {
      // Sin espacio o sin permiso: queda en memoria y se baja la próxima vez.
    }
    return bajada;
  }

  /// Borra las fotos guardadas: las de la memoria y las del celular.
  Future<void> olvidarTodo() async {
    _enMemoria.clear();
    try {
      if (await _carpeta.exists()) await _carpeta.delete(recursive: true);
    } on FileSystemException {
      // Si no se pudo, el sistema la vacía con el tiempo.
    }
  }

  /// Al cerrar sesión: las de la compartida y las del celular.
  static Future<void> olvidarTodas() async {
    await (_compartida?.olvidarTodo() ?? Future<void>.value());
    try {
      final carpeta = carpetaPorDefecto;
      if (await carpeta.exists()) await carpeta.delete(recursive: true);
    } on FileSystemException {
      // Si no se pudo, el sistema la vacía con el tiempo.
    }
  }

  /// Un nombre de archivo fijo para cada dirección (FNV-1a de 64 bits): la
  /// dirección trae caracteres que no valen en un nombre de archivo.
  static String _nombre(String url) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(url)) {
      h ^= b;
      // Los int de Dart son de 64 bits: el producto se recorta solo.
      h *= 0x100000001b3;
    }
    // Sin signo: un nombre que empieza por "-" confunde a algunas
    // herramientas.
    final alto = (h >> 32) & 0xFFFFFFFF;
    final bajo = h & 0xFFFFFFFF;
    return '${alto.toRadixString(16).padLeft(8, '0')}'
        '${bajo.toRadixString(16).padLeft(8, '0')}.img';
  }
}
