import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/utils/csv_inscritos.dart';
import 'package:smart_check/utils/hoja_de_calculo.dart';

/// Arma en memoria un .xls (Excel 97-2003) con datos inventados, igual que
/// el que guarda el docente: un archivo CFB con un flujo `Workbook` BIFF8.
/// Así el test no depende de un archivo real con datos de estudiantes.
Uint8List xls({bool pequeno = false}) {
  final libro = BytesBuilder();
  void registro(int tipo, List<int> datos) {
    libro.add(_u16(tipo));
    libro.add(_u16(datos.length));
    libro.add(datos);
  }

  List<int> bof(int tipo) =>
      [..._u16(0x0600), ..._u16(tipo), ...List.filled(12, 0)];
  List<int> comprimido(String s) =>
      [..._u16(s.length), 0x00, ...latin1.encode(s)];

  // Datos del libro: los textos compartidos (SST). El último se parte en un
  // CONTINUE que sigue en UTF-16, como hace Excel con los textos largos.
  registro(0x0809, bof(0x0005));
  final textos = ['DOCUMENTO', 'NOMBRECOMPLETO', 'MAIL_INST', 'Ana María Pérez'];
  const partido = 'Óscar Patiño';
  registro(0x00FC, [
    ..._u32(7),
    ..._u32(textos.length + 1),
    for (final t in textos) ...comprimido(t),
    ..._u16(partido.length),
    0x00,
    ...latin1.encode(partido.substring(0, 5)),
  ]);
  registro(0x003C, [
    0x01, // Lo que sigue va en 16 bits.
    for (final c in partido.substring(5).codeUnits) ..._u16(c),
  ]);
  registro(0x000A, []);

  // La primera hoja.
  List<int> celda(int fila, int columna) =>
      [..._u16(fila), ..._u16(columna), ..._u16(0)];
  registro(0x0809, bof(0x0010));
  registro(0x0204, [
    ...celda(0, 0),
    ...comprimido('UNIVERSIDAD DE LA AMAZONIA'),
  ]);
  for (var c = 0; c < 3; c++) {
    registro(0x00FD, [...celda(1, c), ..._u32(c)]);
  }
  registro(0x0203, [...celda(2, 0), ..._f64(1117000001)]);
  registro(0x00FD, [...celda(2, 1), ..._u32(3)]);
  registro(0x00FD, [...celda(2, 2), ..._u32(1)]); // Mal puesto a propósito.
  registro(0x0204, [...celda(2, 2), ...comprimido('an.perez@udla.edu.co')]);
  registro(0x0203, [...celda(3, 0), ..._f64(1117000002)]);
  registro(0x00FD, [...celda(3, 1), ..._u32(4)]);
  registro(0x0204, [...celda(3, 2), ...comprimido('os.patino@udla.edu.co')]);
  // Un número entero comprimido (RK) en una cuarta columna.
  registro(0x027E, [...celda(3, 3), ..._u32((2026 << 2) | 0x02)]);
  registro(0x000A, []);

  // Una segunda hoja que no se debe leer.
  registro(0x0809, bof(0x0010));
  registro(0x0204, [...celda(9, 0), ...comprimido('OTRA HOJA')]);
  registro(0x000A, []);

  var flujo = libro.takeBytes();
  if (!pequeno && flujo.length < 4096) {
    // Relleno con un registro que nadie lee, para pasar del mini flujo.
    final faltan = 4096 - flujo.length;
    flujo = Uint8List.fromList([
      ...flujo,
      ..._u16(0x00EF),
      ..._u16(faltan),
      ...List.filled(faltan, 0),
    ]);
  }
  return _cfb(flujo);
}

/// Un CFB versión 3 (sectores de 512) con un solo flujo `Workbook`. Si el
/// flujo mide menos de 4096 bytes va en el mini flujo, como en Excel.
Uint8List _cfb(Uint8List flujo) {
  const sector = 512;
  const fin = 0xFFFFFFFE;
  const libre = 0xFFFFFFFF;
  const sectorFat = 0xFFFFFFFD;
  final mini = flujo.length < 4096;

  // Sectores: 0 FAT, 1 directorio, 2 mini FAT (si hay), luego los datos.
  final datos = <Uint8List>[];
  final fat = List<int>.filled(sector ~/ 4, libre);
  fat[0] = sectorFat;
  fat[1] = fin;
  var siguiente = 2;
  int encadenar(int cuantos) {
    final inicio = siguiente;
    for (var i = 0; i < cuantos; i++) {
      fat[siguiente + i] = i == cuantos - 1 ? fin : siguiente + i + 1;
    }
    siguiente += cuantos;
    return inicio;
  }

  Uint8List relleno(Uint8List b, int multiplo) {
    final largo = ((b.length + multiplo - 1) ~/ multiplo) * multiplo;
    return Uint8List(largo)..setAll(0, b);
  }

  int inicioMiniFat = fin;
  int inicioRaiz = fin;
  int tamanoRaiz = 0;
  int inicioFlujo;
  if (mini) {
    // Mini FAT: el flujo ocupa mini sectores de 64 bytes encadenados.
    final miniSectores = (flujo.length + 63) ~/ 64;
    final miniFat = Uint8List(sector);
    final md = ByteData.sublistView(miniFat);
    for (var i = 0; i < sector ~/ 4; i++) {
      md.setUint32(
        i * 4,
        i < miniSectores ? (i == miniSectores - 1 ? fin : i + 1) : libre,
        Endian.little,
      );
    }
    inicioMiniFat = encadenar(1);
    datos.add(miniFat);
    final miniFlujo = relleno(flujo, 64);
    final enSectores = relleno(miniFlujo, sector);
    inicioRaiz = encadenar(enSectores.length ~/ sector);
    tamanoRaiz = miniFlujo.length;
    datos.add(enSectores);
    inicioFlujo = 0;
  } else {
    final enSectores = relleno(flujo, sector);
    inicioFlujo = encadenar(enSectores.length ~/ sector);
    datos.add(enSectores);
  }

  Uint8List entrada(String nombre, int tipo, int inicio, int tamano, int hijo) {
    final e = Uint8List(128);
    final ed = ByteData.sublistView(e);
    for (var i = 0; i < nombre.length; i++) {
      ed.setUint16(i * 2, nombre.codeUnitAt(i), Endian.little);
    }
    ed.setUint16(0x40, (nombre.length + 1) * 2, Endian.little);
    e[0x42] = tipo;
    ed.setUint32(0x44, libre, Endian.little);
    ed.setUint32(0x48, libre, Endian.little);
    ed.setUint32(0x4C, hijo, Endian.little);
    ed.setUint32(0x74, inicio, Endian.little);
    ed.setUint32(0x78, tamano, Endian.little);
    return e;
  }

  final directorio = Uint8List(sector)
    ..setAll(0, entrada('Root Entry', 5, inicioRaiz, tamanoRaiz, 1))
    ..setAll(128, entrada('Workbook', 2, inicioFlujo, flujo.length, libre));

  final cabecera = Uint8List(sector);
  final cd = ByteData.sublistView(cabecera);
  cabecera.setAll(0, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
  cd.setUint16(0x18, 0x3E, Endian.little);
  cd.setUint16(0x1A, 3, Endian.little);
  cd.setUint16(0x1C, 0xFFFE, Endian.little);
  cd.setUint16(0x1E, 9, Endian.little);
  cd.setUint16(0x20, 6, Endian.little);
  cd.setUint32(0x2C, 1, Endian.little);
  cd.setUint32(0x30, 1, Endian.little);
  cd.setUint32(0x38, 4096, Endian.little);
  cd.setUint32(0x3C, inicioMiniFat, Endian.little);
  cd.setUint32(0x40, mini ? 1 : 0, Endian.little);
  cd.setUint32(0x44, fin, Endian.little);
  for (var i = 0; i < 109; i++) {
    cd.setUint32(0x4C + i * 4, i == 0 ? 0 : libre, Endian.little);
  }

  final fatBytes = Uint8List(sector);
  final fd = ByteData.sublistView(fatBytes);
  for (var i = 0; i < fat.length; i++) {
    fd.setUint32(i * 4, fat[i], Endian.little);
  }
  return Uint8List.fromList([
    ...cabecera,
    ...fatBytes,
    ...directorio,
    for (final d in datos) ...d,
  ]);
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) => [..._u16(v & 0xFFFF), ..._u16((v >> 16) & 0xFFFF)];
List<int> _f64(double v) =>
    (ByteData(8)..setFloat64(0, v, Endian.little)).buffer.asUint8List();

/// Un .xlsx mínimo, con la hoja donde dice el libro y no en sheet1.
Uint8List xlsx() {
  final zip = Archive()
    ..addFile(ArchiveFile.string(
      'xl/workbook.xml',
      '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/'
          '2006/relationships"><sheets><sheet name="Lista" sheetId="1" '
          'r:id="rId7"/></sheets></workbook>',
    ))
    ..addFile(ArchiveFile.string(
      'xl/_rels/workbook.xml.rels',
      '<Relationships><Relationship Id="rId7" '
          'Target="worksheets/lista.xml"/></Relationships>',
    ))
    ..addFile(ArchiveFile.string(
      'xl/sharedStrings.xml',
      '<sst><si><t>DOCUMENTO</t></si><si><t>NOMBRECOMPLETO</t></si>'
          '<si><t>MAIL_INST</t></si><si><r><t>Ana </t></r><r><t>Muñoz</t>'
          '</r></si></sst>',
    ))
    ..addFile(ArchiveFile.string(
      'xl/worksheets/lista.xml',
      '<worksheet><sheetData>'
          '<row r="1"><c r="A1" t="inlineStr"><is><t>Lista de clase</t></is>'
          '</c></row>'
          '<row r="3"><c r="A3" t="s"><v>0</v></c><c r="B3" t="s"><v>1</v>'
          '</c><c r="C3" t="s"><v>2</v></c></row>'
          '<row r="4"><c r="A4"><v>1117000003</v></c><c r="B4" t="s"><v>3</v>'
          '</c><c r="C4" t="str"><v>an.munoz@udla.edu.co</v></c></row>'
          '</sheetData></worksheet>',
    ));
  return ZipEncoder().encodeBytes(zip);
}

void main() {
  group('xls de Excel 97-2003', () {
    for (final pequeno in [false, true]) {
      test(pequeno ? 'en el mini flujo' : 'en sectores normales', () {
        final filas = leerHojaDeCalculo(xls(pequeno: pequeno));

        expect(filas.first.first, 'UNIVERSIDAD DE LA AMAZONIA');
        expect(filas[1].take(3), ['DOCUMENTO', 'NOMBRECOMPLETO', 'MAIL_INST']);
        // La cédula viene como número y se escribe sin decimales.
        expect(filas[2][0], '1117000001');
        // El texto partido entre el SST y su CONTINUE, con tilde y Ñ.
        expect(filas[3][1], 'Óscar Patiño');
        expect(filas[3][3], '2026');
        // La segunda hoja no se mezcla.
        expect(filas.expand((f) => f), isNot(contains('OTRA HOJA')));
      });
    }

    test('salta los títulos de arriba y saca los inscritos', () {
      final r = parsearInscritos(textoDesdeFilas(leerHojaDeCalculo(xls())));

      expect(r.columnaCedula, 'DOCUMENTO');
      expect(r.columnaNombre, 'NOMBRECOMPLETO');
      expect(r.columnaCorreo, 'MAIL_INST');
      expect(r.inscritos.map((i) => i.cedula), ['1117000001', '1117000002']);
      // En mayúsculas, como los guarda Chairá.
      expect(r.inscritos.map((i) => i.nombre), [
        'ANA MARÍA PÉREZ',
        'ÓSCAR PATIÑO',
      ]);
      expect(r.inscritos.last.email, 'os.patino@udla.edu.co');
      expect(r.errores, isEmpty);
    });

    test('un archivo CFB sin libro de Excel da un mensaje claro', () {
      // Se borra el directorio: ya no hay flujo "Workbook" que encontrar.
      final roto = xls()..fillRange(1024, 1536, 0);
      expect(
        () => leerHojaDeCalculo(roto),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('xlsx: textos compartidos, en línea y la hoja que dice el libro', () {
    final filas = leerHojaDeCalculo(xlsx());
    final r = parsearInscritos(textoDesdeFilas(filas));

    expect(filas.first.first, 'Lista de clase');
    expect(r.inscritos.single.cedula, '1117000003');
    expect(r.inscritos.single.nombre, 'ANA MUÑOZ');
    expect(r.inscritos.single.email, 'an.munoz@udla.edu.co');
  });

  group('csv', () {
    test('guardado por Excel en Windows (Latin-1) conserva las tildes', () {
      final bytes = Uint8List.fromList(latin1.encode(
        'DOCUMENTO;NOMBRECOMPLETO;MAIL_INST\r\n'
        '1117000004;José Ñañez;jo.nanez@udla.edu.co\r\n',
      ));
      final r = parsearInscritos(textoDesdeFilas(leerHojaDeCalculo(bytes)));

      expect(r.inscritos.single.nombre, 'JOSÉ ÑAÑEZ');
    });

    test('en UTF-8 con BOM', () {
      final bytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF,
        ...utf8.encode('Cédula,Nombre,Correo\n1117000005,Lucía,lu@udla.edu.co'),
      ]);
      final r = parsearInscritos(textoDesdeFilas(leerHojaDeCalculo(bytes)));

      expect(r.columnaCedula, 'Cédula');
      expect(r.inscritos.single.nombre, 'LUCÍA');
    });
  });

  test('un archivo vacío avisa', () {
    expect(
      () => leerHojaDeCalculo(Uint8List(0)),
      throwsA(isA<FormatException>()),
    );
  });
}
