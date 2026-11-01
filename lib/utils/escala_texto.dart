import 'package:flutter/widgets.dart';

/// La escala de letra más grande que respeta la app.
///
/// El sistema puede pedir mucho más (en algunos Samsung, el doble). Hasta
/// aquí las pantallas están probadas en un teléfono de 320 dp de ancho
/// (`test/responsive_test.dart`); más allá, el diseño ya no cabe y los textos
/// se cortarían. Es el "Más grande" de Android estándar.
const escalaMaximaDeTexto = 1.3;

/// Para `MaterialApp.builder`: deja la letra del sistema, pero sin pasar de
/// [escalaMaximaDeTexto].
Widget limitarEscalaDeTexto(BuildContext context, Widget? child) {
  final consulta = MediaQuery.of(context);
  return MediaQuery(
    data: consulta.copyWith(
      textScaler: consulta.textScaler.clamp(
        maxScaleFactor: escalaMaximaDeTexto,
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
