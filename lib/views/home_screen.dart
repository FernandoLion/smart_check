import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usuario_perfil_model.dart';
import '../utils/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';

/// Pantalla de llegada después del login.
///
/// En la app completa aquí estarían el panel docente o el del estudiante.
/// Para la sustentación basta con mostrar quién entró y con qué rol, y
/// poder cerrar la sesión.
class HomeScreen extends StatelessWidget {
  final String rol;

  const HomeScreen({super.key, required this.rol});

  @override
  Widget build(BuildContext context) {
    final perfil = context.watch<AuthViewModel>().perfil;
    final esDocente = rol == Rol.docente;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  esDocente ? Icons.school : Icons.badge,
                  size: 64,
                  color: esDocente ? AppTheme.primary : AppTheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido, ${esDocente ? 'docente' : 'estudiante'}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  perfil?.nombre ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  perfil?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => _cerrarSesion(context),
                  icon: const Icon(Icons.logout, color: AppTheme.error),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cierra la sesión en Firebase y vuelve al login.
  Future<void> _cerrarSesion(BuildContext context) async {
    await context.read<AuthViewModel>().signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}
