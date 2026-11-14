import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// El símbolo de SmartCheck: un check dentro de las ondas de un radar.
///
/// Se dibuja con código (no es una imagen), así que se ve nítido a cualquier
/// tamaño. Es el mismo dibujo de `assets/branding/smartcheck_mark.svg`.
class SmartCheckLogo extends StatelessWidget {
  const SmartCheckLogo({super.key, this.size = 40, this.semanticLabel});

  final double size;

  /// Lo que dice el lector de pantalla. Si el logo va al lado del nombre
  /// "SmartCheck", se deja en null para que no lo lea dos veces.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _SmartCheckLogoPainter()),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: logo);
    return Semantics(label: semanticLabel, image: true, child: logo);
  }
}

/// El nombre "SmartCheck" con "Check" en índigo, como en el logo.
class SmartCheckNombre extends StatelessWidget {
  const SmartCheckNombre({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Smart', style: base),
          TextSpan(
            text: 'Check',
            style: base.copyWith(color: AppTheme.primaryTexto),
          ),
        ],
      ),
      semanticsLabel: 'SmartCheck',
    );
  }
}

class _SmartCheckLogoPainter extends CustomPainter {
  const _SmartCheckLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // El dibujo original mide 512 × 512.
    final s = size.shortestSide / 512;
    final centro = Offset(size.width / 2, size.height / 2);

    final onda = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24 * s;
    canvas.drawCircle(
      centro,
      226 * s,
      onda..color = AppTheme.primary.withValues(alpha: 0.32),
    );
    canvas.drawCircle(
      centro,
      168 * s,
      onda..color = AppTheme.primary.withValues(alpha: 0.62),
    );

    canvas.drawCircle(centro, 110 * s, Paint()..color = AppTheme.primary);

    final origen = centro - Offset(256 * s, 256 * s);
    final check = Path()
      ..moveTo(origen.dx + 200 * s, origen.dy + 258 * s)
      ..lineTo(origen.dx + 240 * s, origen.dy + 298 * s)
      ..lineTo(origen.dx + 314 * s, origen.dy + 218 * s);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SmartCheckLogoPainter oldDelegate) => false;
}
