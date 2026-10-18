import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/utils/usuario_input_formatter.dart';

void main() {
  String formatear(String texto) => UsuarioInstitucionalFormatter()
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: texto,
          selection: TextSelection.collapsed(offset: texto.length),
        ),
      )
      .text;

  test('deja solo el usuario aunque se pegue el correo completo', () {
    expect(formatear('an.perez'), 'an.perez');
    expect(formatear('AN.Perez'), 'an.perez');
    expect(formatear(' an.perez '), 'an.perez');
    expect(formatear('AN.Perez@UDLA.edu.co'), 'an.perez');
  });

  test('al escribir el correo letra por letra queda solo el usuario', () {
    var valor = TextEditingValue.empty;
    for (final letra in 'an.perez@udla.edu.co'.split('')) {
      final texto = valor.text + letra;
      valor = UsuarioInstitucionalFormatter().formatEditUpdate(
        valor,
        TextEditingValue(
          text: texto,
          selection: TextSelection.collapsed(offset: texto.length),
        ),
      );
    }
    expect(valor.text, 'an.perez');
  });

  test('deja otros dominios para que la validación los rechace', () {
    expect(formatear('an.perez@gmail.com'), 'an.perez@gmail.com');
  });
}
