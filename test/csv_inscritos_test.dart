import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/utils/csv_inscritos.dart';

void main() {
  test('lee columnas por encabezado con punto y coma', () {
    final r = parsearInscritos(
      'Cédula;Nombre;Correo\n'
      '1.117.000.000;Ana María Pérez Gómez;An.Perez@udla.edu.co\n'
      '1117000002;Carlos Andrés Muñoz Rivera;\n',
    );

    expect(r.errores, isEmpty);
    expect(r.inscritos, hasLength(2));
    expect(r.inscritos[0].cedula, '1117000000');
    expect(r.inscritos[0].email, 'an.perez@udla.edu.co');
    expect(r.inscritos[0].nombre, 'ANA MARÍA PÉREZ GÓMEZ');
    expect(r.inscritos[1].email, isNull);
  });

  test('reconoce celdas por su forma cuando no hay encabezado (Excel)', () {
    final r = parsearInscritos(
      'Ana María\tPérez Gómez\t1117000000\n'
      'ca.munoz@udla.edu.co\tCarlos Muñoz\n',
    );

    expect(r.inscritos, hasLength(2));
    expect(r.inscritos[0].cedula, '1117000000');
    expect(r.inscritos[0].nombre, 'ANA MARÍA PÉREZ GÓMEZ');
    expect(r.inscritos[1].cedula, isNull);
    expect(r.inscritos[1].clave, 'ca.munoz@udla.edu.co');
  });

  test('acepta comas y comillas', () {
    final r = parsearInscritos('"1117000000","Ana Pérez"');
    expect(r.inscritos.single.cedula, '1117000000');
    expect(r.inscritos.single.nombre, 'ANA PÉREZ');
  });

  test('ignora vacías y repetidos, y reporta filas sin cédula ni correo', () {
    final r = parsearInscritos(
      '1117000000,Ana\n'
      '\n'
      '1117000000,Ana otra vez\n'
      'Sin datos de contacto\n',
    );

    expect(r.inscritos, hasLength(1));
    expect(r.errores, ['Línea 4: falta la cédula o el correo.']);
  });

  test('usa el usuario del correo como nombre si falta', () {
    final r = parsearInscritos('an.perez@udla.edu.co');
    expect(r.inscritos.single.nombre, 'AN.PEREZ');
  });

  group('Excel de la universidad', () {
    const encabezado = 'PROGRAMA\tCODIGOESTUDIANTE\tFECHAMATRICULA\tMAIL_INST\t'
        'DOCUMENTO\tNOMBRECOMPLETO\tPENG_IDENTITARIO\tTELEFONO\tEPS';
    const fila1 = 'INGENIERIA DE SISTEMAS\t4000000001\t15/01/2026\t'
        'An.Perez@udla.edu.co\t1117000000\tPÉREZ GÓMEZ ANA MARÍA\tNINGUNO\t'
        '3100000000\tNUEVA EPS';
    const fila2 = 'INGENIERIA DE SISTEMAS\t5000000002\t15/01/2026\t'
        'ca.munoz@udla.edu.co\t1.117.000.002\tMUÑOZ RIVERA CARLOS ANDRÉS\t'
        'NINGUNO\t3200000000\tSANITAS';

    test('toma DOCUMENTO, NOMBRECOMPLETO y MAIL_INST, no el código', () {
      final r = parsearInscritos('$encabezado\n$fila1\n$fila2\n');

      expect(r.errores, isEmpty);
      expect(r.columnaCedula, 'DOCUMENTO');
      expect(r.columnaNombre, 'NOMBRECOMPLETO');
      expect(r.columnaCorreo, 'MAIL_INST');
      expect(r.inscritos, hasLength(2));
      expect(r.inscritos[0].cedula, '1117000000');
      expect(r.inscritos[0].nombre, 'PÉREZ GÓMEZ ANA MARÍA');
      expect(r.inscritos[0].email, 'an.perez@udla.edu.co');
      expect(r.inscritos[0].claves, ['1117000000', 'an.perez@udla.edu.co']);
      expect(r.inscritos[1].cedula, '1117000002');
    });

    test('sin la fila de títulos pide copiarla', () {
      final r = parsearInscritos('$fila1\n$fila2');

      expect(r.inscritos, isEmpty);
      expect(r.errores.single, contains('fila de títulos'));
    });
  });

  test('ignora "Tipo de documento" y prefiere el correo institucional', () {
    final r = parsearInscritos(
      'Tipo de documento;Número de documento;Correo personal;'
      'Correo institucional;Nombre del estudiante\n'
      'CC;1117000000;ana@gmail.com;an.perez@udla.edu.co;Ana Pérez\n',
    );

    expect(r.columnaCedula, 'Número de documento');
    expect(r.columnaCorreo, 'Correo institucional');
    expect(r.inscritos.single.cedula, '1117000000');
    expect(r.inscritos.single.email, 'an.perez@udla.edu.co');
    expect(r.inscritos.single.nombre, 'ANA PÉREZ');
  });

  test('una primera fila de datos no se toma como títulos', () {
    final r = parsearInscritos(
      'Ismail Pérez\tis.perez@udla.edu.co\n'
      'Ana Pérez\tan.perez@udla.edu.co\n',
    );
    expect(r.conEncabezado, isFalse);
    expect(r.inscritos, hasLength(2));
    expect(r.inscritos.first.nombre, 'ISMAIL PÉREZ');
  });

  test('un nombre sin letras se cambia por el usuario del correo', () {
    final r = parsearInscritos(
      'Documento;Nombre;Correo\n1117000000;4000000001;an.perez@udla.edu.co',
    );
    expect(r.inscritos.single.nombre, 'AN.PEREZ');
  });

  test('texto vacío no da estudiantes ni errores', () {
    final r = parsearInscritos('  \n ');
    expect(r.inscritos, isEmpty);
    expect(r.errores, isEmpty);
  });
}
