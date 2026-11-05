import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lee la primera hoja de un archivo de estudiantes: Excel viejo (.xls, el
/// que suele guardar el docente), Excel nuevo (.xlsx) o CSV.
///
/// Devuelve las filas como celdas de texto. El formato se reconoce por los
/// primeros bytes y no por la extensión, porque un .xls renombrado o un CSV
/// guardado como .xls son comunes. Lanza [FormatException] con un mensaje
/// para mostrar si no lo puede leer.
List<List<String>> leerHojaDeCalculo(Uint8List bytes) {
  if (bytes.isEmpty) throw const FormatException('El archivo está vacío.');
  if (_empiezaCon(bytes, const [0xD0, 0xCF, 0x11, 0xE0])) {
    return _leerXls(bytes);
  }
  if (_empiezaCon(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    return _leerXlsx(bytes);
  }
  return _leerTexto(bytes);
}

bool _empiezaCon(Uint8List bytes, List<int> firma) {
  if (bytes.length < firma.length) return false;
  for (var i = 0; i < firma.length; i++) {
    if (bytes[i] != firma[i]) return false;
  }
  return true;
}

// --- CSV y texto --------------------------------------------------------------

/// Un CSV guardado desde Excel en Windows viene en Windows-1252, no en UTF-8:
/// si no es UTF-8 válido se lee como Latin-1, que coincide en las letras
/// del español (á, ñ...).
List<List<String>> _leerTexto(Uint8List bytes) {
  String texto;
  try {
    texto = utf8.decode(bytes);
  } on FormatException {
    texto = latin1.decode(bytes);
  }
  if (texto.startsWith('﻿')) texto = texto.substring(1);
  final lineas = texto.split(RegExp(r'\r?\n'));
  final muestra = lineas.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final separador = muestra.contains('\t')
      ? '\t'
      : muestra.contains(';')
          ? ';'
          : ',';
  return [
    for (final linea in lineas)
      linea
          .split(separador)
          .map((c) => c.trim().replaceAll(RegExp(r'^"|"$'), '').trim())
          .toList(),
  ];
}

// --- .xlsx ------------------------------------------------------------------

List<List<String>> _leerXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('El archivo .xlsx está dañado.');
  }
  String? texto(String ruta) {
    final archivo = zip.findFile(ruta);
    return archivo == null ? null : utf8.decode(archivo.content);
  }

  // Los textos repetidos se guardan una sola vez y las celdas los citan.
  final compartidos = <String>[];
  final sst = texto('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in XmlDocument.parse(sst).findAllElements('si')) {
      compartidos.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  final hoja = texto(_rutaPrimeraHoja(texto) ?? 'xl/worksheets/sheet1.xml');
  if (hoja == null) {
    throw const FormatException('El archivo .xlsx no tiene hojas.');
  }
  final filas = <int, Map<int, String>>{};
  for (final fila in XmlDocument.parse(hoja).findAllElements('row')) {
    final numero = int.tryParse(fila.getAttribute('r') ?? '') ?? filas.length + 1;
    for (final c in fila.findElements('c')) {
      final columna = _columnaDeReferencia(c.getAttribute('r') ?? '');
      if (columna == null) continue;
      final tipo = c.getAttribute('t');
      final v = c.getElement('v')?.innerText;
      final String valor;
      if (tipo == 's') {
        final i = int.tryParse(v ?? '');
        valor = i != null && i < compartidos.length ? compartidos[i] : '';
      } else if (tipo == 'inlineStr') {
        valor = c.findAllElements('t').map((t) => t.innerText).join();
      } else if (tipo == 'str' || tipo == 'b' || tipo == 'e') {
        valor = v ?? '';
      } else {
        final n = double.tryParse(v ?? '');
        valor = n == null ? (v ?? '') : _numero(n);
      }
      (filas[numero] ??= {})[columna] = valor;
    }
  }
  return _comoTabla(filas);
}

/// La ruta de la primera hoja según el libro, que no siempre es sheet1.
String? _rutaPrimeraHoja(String? Function(String) texto) {
  final libro = texto('xl/workbook.xml');
  final relaciones = texto('xl/_rels/workbook.xml.rels');
  if (libro == null || relaciones == null) return null;
  final primera = XmlDocument.parse(libro).findAllElements('sheet').firstOrNull;
  final id = primera?.attributes
      .where((a) => a.name.local == 'id')
      .firstOrNull
      ?.value;
  if (id == null) return null;
  for (final r in XmlDocument.parse(relaciones).findAllElements('Relationship')) {
    if (r.getAttribute('Id') != id) continue;
    final destino = r.getAttribute('Target') ?? '';
    return destino.startsWith('/')
        ? destino.substring(1)
        : 'xl/${destino.replaceFirst(RegExp(r'^\./'), '')}';
  }
  return null;
}

/// "C12" -> 2 (columnas desde 0).
int? _columnaDeReferencia(String referencia) {
  final letras = RegExp(r'^[A-Z]+').stringMatch(referencia.toUpperCase());
  if (letras == null) return null;
  var n = 0;
  for (final c in letras.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

// --- .xls (Excel 97-2003) -----------------------------------------------------

/// El .xls es un "archivo dentro de un archivo" (Compound File Binary) con
/// un flujo `Workbook` de registros BIFF8. Se lee lo justo para sacar el
/// texto y los números de las celdas de la primera hoja.
List<List<String>> _leerXls(Uint8List bytes) {
  final Uint8List libro;
  try {
    libro = _flujoDeCfb(bytes, 'Workbook');
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('El archivo .xls está dañado.');
  }
  try {
    return _comoTabla(_celdasBiff8(libro));
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'No se pudo leer el .xls. Ábrelo en Excel y guárdalo como .xlsx o CSV.',
    );
  }
}

const _finDeCadena = 0xFFFFFFFA; // De aquí para arriba son marcas, no sectores.

Uint8List _flujoDeCfb(Uint8List bytes, String nombreBuscado) {
  final d = ByteData.sublistView(bytes);
  int u16(int o) => d.getUint16(o, Endian.little);
  int u32(int o) => d.getUint32(o, Endian.little);

  final sector = 1 << u16(0x1E);
  final mini = 1 << u16(0x20);
  final sectoresFat = u32(0x2C);
  final inicioDirectorio = u32(0x30);
  final corte = u32(0x38);
  final inicioMiniFat = u32(0x3C);
  var difat = u32(0x44);

  int offset(int s) => (s + 1) * sector;

  // Dónde está la tabla de asignación (FAT): las primeras 109 entradas van
  // en la cabecera y el resto en sectores DIFAT encadenados.
  final ubicacionesFat = <int>[];
  for (var i = 0; i < 109 && ubicacionesFat.length < sectoresFat; i++) {
    final s = u32(0x4C + i * 4);
    if (s < _finDeCadena) ubicacionesFat.add(s);
  }
  final porSector = sector ~/ 4;
  for (var vueltas = 0;
      ubicacionesFat.length < sectoresFat && difat < _finDeCadena && vueltas < 1000;
      vueltas++) {
    final o = offset(difat);
    for (var i = 0; i < porSector - 1 && ubicacionesFat.length < sectoresFat; i++) {
      final s = u32(o + i * 4);
      if (s < _finDeCadena) ubicacionesFat.add(s);
    }
    difat = u32(o + (porSector - 1) * 4);
  }
  final fat = <int>[
    for (final s in ubicacionesFat)
      for (var i = 0; i < porSector; i++)
        if (offset(s) + i * 4 + 4 <= bytes.length) u32(offset(s) + i * 4),
  ];

  List<int> cadena(int inicio, List<int> tabla) {
    final sectores = <int>[];
    final vistos = <int>{};
    var s = inicio;
    while (s < _finDeCadena && s < tabla.length && vistos.add(s)) {
      sectores.add(s);
      s = tabla[s];
    }
    return sectores;
  }

  Uint8List leer(int inicio, int? tamano) {
    final b = BytesBuilder(copy: false);
    for (final s in cadena(inicio, fat)) {
      final o = offset(s);
      if (o >= bytes.length) break;
      b.add(Uint8List.sublistView(bytes, o, min(o + sector, bytes.length)));
    }
    final todo = b.takeBytes();
    return tamano != null && tamano < todo.length
        ? Uint8List.sublistView(todo, 0, tamano)
        : todo;
  }

  final directorio = leer(inicioDirectorio, null);
  final dd = ByteData.sublistView(directorio);
  int? inicioMiniFlujo, tamanoMiniFlujo;
  for (var e = 0; e + 128 <= directorio.length; e += 128) {
    final largo = dd.getUint16(e + 0x40, Endian.little);
    final tipo = directorio[e + 0x42];
    final inicio = dd.getUint32(e + 0x74, Endian.little);
    final tamano = dd.getUint32(e + 0x78, Endian.little);
    if (tipo == 5) {
      // La raíz guarda el "mini flujo" donde viven los flujos pequeños.
      inicioMiniFlujo = inicio;
      tamanoMiniFlujo = tamano;
      continue;
    }
    if (tipo != 2 || largo < 2) continue;
    final nombre = String.fromCharCodes([
      for (var i = 0; i < (largo - 2) ~/ 2; i++)
        dd.getUint16(e + i * 2, Endian.little),
    ]);
    if (nombre == 'Book') {
      throw const FormatException(
        'Este .xls es de Excel 95. Ábrelo en Excel y guárdalo como .xlsx.',
      );
    }
    if (nombre != nombreBuscado) continue;
    if (tamano >= corte) return leer(inicio, tamano);

    // Flujo pequeño: está en el mini flujo, en trozos de [mini] bytes.
    final miniFlujo = leer(inicioMiniFlujo ?? _finDeCadena, tamanoMiniFlujo);
    final miniFatBytes = leer(inicioMiniFat, null);
    final md = ByteData.sublistView(miniFatBytes);
    final miniFat = [
      for (var i = 0; i + 4 <= miniFatBytes.length; i += 4)
        md.getUint32(i, Endian.little),
    ];
    final b = BytesBuilder(copy: false);
    for (final s in cadena(inicio, miniFat)) {
      final o = s * mini;
      if (o >= miniFlujo.length) break;
      b.add(Uint8List.sublistView(miniFlujo, o, min(o + mini, miniFlujo.length)));
    }
    final todo = b.takeBytes();
    return tamano < todo.length ? Uint8List.sublistView(todo, 0, tamano) : todo;
  }
  throw const FormatException(
    'Este archivo no es un libro de Excel. Ábrelo en Excel y guárdalo como '
    '.xlsx o CSV.',
  );
}

Map<int, Map<int, String>> _celdasBiff8(Uint8List libro) {
  final d = ByteData.sublistView(libro);
  final celdas = <int, Map<int, String>>{};
  final compartidos = <String>[];
  var hoja = -1; // -1: datos globales del libro; 0: primera hoja.
  int? formulaFila, formulaColumna;

  void poner(int fila, int columna, String valor) {
    if (hoja == 0) (celdas[fila] ??= {})[columna] = valor;
  }

  var pos = 0;
  while (pos + 4 <= libro.length) {
    final tipo = d.getUint16(pos, Endian.little);
    final largo = d.getUint16(pos + 2, Endian.little);
    final inicio = pos + 4;
    final fin = min(inicio + largo, libro.length);
    final datos = Uint8List.sublistView(libro, inicio, fin);
    final rd = ByteData.sublistView(datos);
    int u16(int o) => rd.getUint16(o, Endian.little);
    pos = fin;

    switch (tipo) {
      case 0x0809: // BOF: empieza el libro o una hoja.
        if (datos.length >= 4 && u16(2) == 0x0010) hoja++;
        if (hoja > 0) return celdas;
      case 0x000A: // EOF
        if (hoja == 0) return celdas;
      case 0x00FC: // SST: los textos del libro, quizá partidos en CONTINUE.
        final trozos = [datos];
        while (pos + 4 <= libro.length &&
            d.getUint16(pos, Endian.little) == 0x003C) {
          final l = d.getUint16(pos + 2, Endian.little);
          trozos.add(
            Uint8List.sublistView(libro, pos + 4, min(pos + 4 + l, libro.length)),
          );
          pos = min(pos + 4 + l, libro.length);
        }
        compartidos.addAll(_textosCompartidos(trozos));
      case 0x00FD: // LABELSST: celda con un texto del SST.
        if (datos.length >= 10) {
          final i = rd.getUint32(6, Endian.little);
          poner(u16(0), u16(2), i < compartidos.length ? compartidos[i] : '');
        }
      case 0x0204: // LABEL: texto en la propia celda.
        if (datos.length >= 9) {
          final lector = _Trozos([Uint8List.sublistView(datos, 6)]);
          final cch = lector.u16();
          poner(u16(0), u16(2), lector.caracteres(cch, (lector.u8() & 1) == 1));
        }
      case 0x0203: // NUMBER
        if (datos.length >= 14) {
          poner(u16(0), u16(2), _numero(rd.getFloat64(6, Endian.little)));
        }
      case 0x027E: // RK: número comprimido.
        if (datos.length >= 10) {
          poner(u16(0), u16(2), _numero(_rk(rd.getUint32(6, Endian.little))));
        }
      case 0x00BD: // MULRK: varios RK seguidos en una fila.
        final fila = u16(0);
        var columna = u16(2);
        for (var o = 4; o + 6 <= datos.length - 2; o += 6, columna++) {
          poner(fila, columna, _numero(_rk(rd.getUint32(o + 2, Endian.little))));
        }
      case 0x0006: // FORMULA: se toma el resultado guardado.
        if (datos.length >= 14) {
          if (datos[12] == 0xFF && datos[13] == 0xFF) {
            if (datos[6] == 0) {
              // El texto viene en el registro STRING que sigue.
              formulaFila = u16(0);
              formulaColumna = u16(2);
            }
          } else {
            poner(u16(0), u16(2), _numero(rd.getFloat64(6, Endian.little)));
          }
        }
      case 0x0207: // STRING: resultado de texto de la fórmula anterior.
        if (formulaFila != null && datos.length >= 3) {
          final lector = _Trozos([datos]);
          final cch = lector.u16();
          poner(
            formulaFila,
            formulaColumna!,
            lector.caracteres(cch, (lector.u8() & 1) == 1),
          );
        }
        formulaFila = null;
    }
  }
  return celdas;
}

/// Los textos del SST. Cada uno: largo, opciones (16 bits o comprimido,
/// formato enriquecido, datos fonéticos) y caracteres; si los caracteres
/// cruzan a un CONTINUE, este empieza con un byte que dice cómo siguen.
List<String> _textosCompartidos(List<Uint8List> trozos) {
  final lector = _Trozos(trozos);
  lector.u32(); // Total de usos.
  final unicos = lector.u32();
  final textos = <String>[];
  for (var k = 0; k < unicos && !lector.agotado; k++) {
    final cch = lector.u16();
    final opciones = lector.u8();
    final corridas = (opciones & 0x08) != 0 ? lector.u16() : 0;
    final extra = (opciones & 0x04) != 0 ? lector.u32() : 0;
    textos.add(lector.caracteres(cch, (opciones & 0x01) != 0));
    lector.saltar(corridas * 4 + extra);
  }
  return textos;
}

class _Trozos {
  final List<Uint8List> trozos;
  int _i = 0;
  int _p = 0;
  _Trozos(this.trozos);

  bool get agotado {
    _avanzar();
    return _i >= trozos.length;
  }

  void _avanzar() {
    while (_i < trozos.length && _p >= trozos[_i].length) {
      _i++;
      _p = 0;
    }
  }

  int u8() {
    _avanzar();
    if (_i >= trozos.length) throw const FormatException('Texto incompleto.');
    return trozos[_i][_p++];
  }

  int u16() => u8() | (u8() << 8);
  int u32() => u16() | (u16() << 16);

  void saltar(int n) {
    for (var k = 0; k < n && !agotado; k++) {
      _p++;
    }
  }

  String caracteres(int cuantos, bool anchos) {
    final sb = StringBuffer();
    var dobles = anchos;
    for (var k = 0; k < cuantos; k++) {
      if (_i < trozos.length && _p >= trozos[_i].length) {
        // Siguen en el CONTINUE, que dice de nuevo si son de 8 o 16 bits.
        _i++;
        _p = 0;
        if (_i >= trozos.length) break;
        dobles = (trozos[_i][_p++] & 0x01) != 0;
      }
      if (_i >= trozos.length) break;
      if (dobles) {
        sb.writeCharCode(u16());
      } else {
        // Comprimido: cada byte es el bajo de UTF-16, o sea Latin-1.
        sb.writeCharCode(u8());
      }
    }
    return sb.toString();
  }
}

/// Un RK es un double recortado a 30 bits o un entero, quizá por 100.
double _rk(int rk) {
  double valor;
  if ((rk & 0x02) != 0) {
    var entero = rk >> 2;
    if (entero & 0x20000000 != 0) entero -= 0x40000000; // Con signo.
    valor = entero.toDouble();
  } else {
    final b = ByteData(8)..setUint32(4, rk & 0xFFFFFFFC, Endian.little);
    valor = b.getFloat64(0, Endian.little);
  }
  return (rk & 0x01) != 0 ? valor / 100 : valor;
}

// --- Comunes -------------------------------------------------------------------

/// Una cédula guardada como número (1117000000.0) se escribe sin decimales.
String _numero(double n) {
  if (n.isFinite && n == n.truncateToDouble() && n.abs() < 1e15) {
    return n.toInt().toString();
  }
  return n.toString();
}

List<List<String>> _comoTabla(Map<int, Map<int, String>> celdas) {
  if (celdas.isEmpty) return const [];
  final filas = celdas.keys.toList()..sort();
  final columnas = celdas.values.expand((f) => f.keys).fold(0, max) + 1;
  return [
    for (final f in filas)
      [for (var c = 0; c < columnas; c++) celdas[f]![c] ?? ''],
  ];
}
