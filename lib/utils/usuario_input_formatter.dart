import 'package:flutter/services.dart';

/// Único dominio de correo que usa la app.
const dominioInstitucional = '@udla.edu.co';

/// Para los campos de usuario con el dominio @udla.edu.co fijo: el usuario
/// escribe solo "jh.leon". Quita espacios, pasa a minúsculas y, si se escribe
/// o pega el correo completo ("jh.leon@udla.edu.co"), lo deja en "jh.leon".
/// Un @ con otro dominio se deja para que la validación lo rechace.
class UsuarioInstitucionalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var texto = newValue.text.toLowerCase().replaceAll(RegExp(r'\s'), '');
    if (texto.endsWith(dominioInstitucional)) {
      texto = texto.substring(0, texto.length - dominioInstitucional.length);
    }
    if (texto == newValue.text) return newValue;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
