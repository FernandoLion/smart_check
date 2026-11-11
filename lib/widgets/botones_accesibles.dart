import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Botón redondo de solo un ícono (ajustes, cerrar, volver...).
///
/// Se ve de 40 de diámetro, pero responde en 48: lo mínimo para tocarlo sin
/// atinarle a otra cosa. [nombre] es lo que lee TalkBack y lo que sale al
/// mantenerlo pulsado: sin él, un ícono suelto no le dice nada a quien no
/// lo reconoce.
class BotonRedondo extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final VoidCallback? onPressed;
  final Color color;
  final Color fondo;
  final double tamanoIcono;

  const BotonRedondo({
    super.key,
    required this.icono,
    required this.nombre,
    required this.onPressed,
    this.color = Colors.white,
    this.fondo = AppTheme.surfaceElevated,
    this.tamanoIcono = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: nombre,
      style: IconButton.styleFrom(
        backgroundColor: fondo,
        disabledBackgroundColor: fondo,
        foregroundColor: color,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: Icon(icono, size: tamanoIcono),
    );
  }
}

/// Zona que responde al toque en al menos 48×48 aunque lo que muestre sea
/// más pequeño (un enlace de texto, una flecha con un título) y que TalkBack
/// anuncia como botón.
///
/// [nombre] hace falta cuando [child] es solo un ícono; si tiene texto,
/// TalkBack ya lee ese texto.
class Tocable extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String? nombre;
  final AlignmentGeometry alineacion;

  const Tocable({
    super.key,
    required this.onTap,
    required this.child,
    this.nombre,
    this.alineacion = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: nombre,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: alineacion,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          ),
        ),
      ),
    );
  }
}
