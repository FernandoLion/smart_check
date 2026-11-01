import 'dart:math';

import 'package:flutter/material.dart';

/// Un [Text] que nunca parte una palabra por la mitad.
///
/// Con la letra grande del sistema y una pantalla angosta, una palabra larga
/// ("automáticamente", "COORDENADAS") puede no caber en el ancho que le toca, y
/// Flutter la corta donde sea ("automáticam / ente"). Este texto mide su
/// palabra más larga y, solo si no cabe, achica la letra lo justo para que
/// quepa. En el resto de los casos es un [Text] normal y hace saltos de línea
/// entre palabras.
///
/// No usar dentro de un `IntrinsicHeight` o `IntrinsicWidth`: necesita saber
/// su ancho y por eso usa un [LayoutBuilder].
class TextoSinCortes extends StatelessWidget {
  final String texto;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Lo más que se achica la letra; por debajo, mejor partir la palabra que
  /// volverla ilegible.
  static const escalaMinima = 0.7;

  const TextoSinCortes(
    this.texto, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    final estilo = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, caja) {
        var escalaFinal = escala;
        final ancho = caja.maxWidth;
        if (ancho.isFinite && ancho > 0) {
          final tamano = estilo.fontSize ?? 14;
          final minima = escala.scale(tamano) / tamano * escalaMinima;
          // La letra no crece en proporción exacta (redondeos, espaciado), así
          // que se vuelve a medir hasta que la palabra quepa.
          var mayor = _palabraMasAncha(estilo, escalaFinal);
          while (mayor > ancho) {
            final actual = escalaFinal.scale(tamano) / tamano;
            if (actual <= minima) break;
            escalaFinal = TextScaler.linear(
              max(actual * ancho / mayor * 0.98, minima),
            );
            mayor = _palabraMasAncha(estilo, escalaFinal);
          }
        }
        return Text(
          texto,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          textScaler: escalaFinal,
        );
      },
    );
  }

  double _palabraMasAncha(TextStyle estilo, TextScaler escala) {
    var mayor = 0.0;
    for (final palabra in texto.split(RegExp(r'\s+'))) {
      if (palabra.isEmpty) continue;
      final medida = TextPainter(
        text: TextSpan(text: palabra, style: estilo),
        textDirection: TextDirection.ltr,
        textScaler: escala,
        maxLines: 1,
      )..layout();
      mayor = max(mayor, medida.width);
      medida.dispose();
    }
    // Un pelo de margen por el redondeo del motor de texto.
    return mayor + 0.5;
  }
}
