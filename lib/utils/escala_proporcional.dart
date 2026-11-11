import 'package:flutter/widgets.dart';

import 'escala_texto.dart';

/// El ancho (en dp) de los celulares más anchos: hasta aquí las pantallas se
/// dibujan tal cual, y de aquí en adelante todo se agranda en proporción.
const anchoDeReferencia = 430.0;

/// Lo más que se agranda la app. En una tablet de 10" (unos 800 dp) ya llega
/// a este tope; más allá, todo se vería enorme.
const escalaMaximaDePantalla = 1.8;

/// Cuánto hay que agrandar la app en una pantalla de [tamano] (en dp): 1 en
/// cualquier celular, y en tablets el lado corto dividido entre
/// [anchoDeReferencia], con tope en [escalaMaximaDePantalla].
double factorDeEscala(Size tamano) =>
    (tamano.shortestSide / anchoDeReferencia).clamp(1.0, escalaMaximaDePantalla);

/// Para `MaterialApp.builder`: la letra del sistema sin pasar de
/// [escalaMaximaDeTexto] y, en pantallas más grandes que un celular, la app
/// entera agrandada en proporción.
///
/// Se arma a un tamaño lógico de celular (el real dividido entre el factor)
/// y se escala completa, así que letras, íconos, botones, márgenes, diálogos
/// y hojas crecen juntos: lo que en el celular mide un 5 % del ancho, en la
/// tablet también. Ninguna pantalla tiene que saberlo.
Widget adaptarAPantalla(BuildContext context, Widget? child) {
  final consulta = MediaQuery.of(context);
  final letra = consulta.textScaler.clamp(maxScaleFactor: escalaMaximaDeTexto);
  final hijo = child ?? const SizedBox.shrink();
  final factor = factorDeEscala(consulta.size);
  if (factor == 1.0) {
    return MediaQuery(data: consulta.copyWith(textScaler: letra), child: hijo);
  }
  final logico = consulta.size / factor;
  return FittedBox(
    fit: BoxFit.fill,
    alignment: Alignment.topLeft,
    child: SizedBox.fromSize(
      size: logico,
      child: MediaQuery(
        data: consulta.copyWith(
          size: logico,
          devicePixelRatio: consulta.devicePixelRatio * factor,
          textScaler: letra,
          padding: consulta.padding / factor,
          viewPadding: consulta.viewPadding / factor,
          viewInsets: consulta.viewInsets / factor,
          systemGestureInsets: consulta.systemGestureInsets / factor,
        ),
        child: hijo,
      ),
    ),
  );
}
