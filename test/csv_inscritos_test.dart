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

  test('texto vacío no da estudiantes ni errores', () {
    final r = parsearInscritos('  \n ');
    expect(r.inscritos, isEmpty);
    expect(r.errores, isEmpty);
  });
}
