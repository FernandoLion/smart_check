import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../views/login_screen.dart';
import '../views/smart_register_screen.dart';

/// Las dos pestañas de arriba: "Iniciar Sesión" y "Registrarse".
///
/// Lo usan las dos pantallas. [enRegistro] dice cuál está marcada; tocar la
/// otra reemplaza la pantalla actual por la otra.
class SelectorIngreso extends StatelessWidget {
  final bool enRegistro;

  const SelectorIngreso({super.key, required this.enRegistro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _pestana(
            context,
            'Iniciar Sesión',
            activa: !enRegistro,
            destino: const LoginScreen(),
          ),
          _pestana(
            context,
            'Registrarse',
            activa: enRegistro,
            destino: const SmartRegisterScreen(),
          ),
        ],
      ),
    );
  }

  Widget _pestana(
    BuildContext context,
    String texto, {
    required bool activa,
    required Widget destino,
  }) {
    return Expanded(
      child: GestureDetector(
        // La pestaña activa no hace nada: ya estamos en esa pantalla.
        onTap: activa
            ? null
            : () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => destino),
              ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: activa ? const Color(0xFF39393b) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: activa
                ? const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
              color: activa ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
