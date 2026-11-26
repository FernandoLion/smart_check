import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/app_theme.dart';
import '../widgets/ajustes_compartidos.dart';

/// Lo que pregunta el login antes de entrar. Las pruebas lo cambian: ahí
/// no hay Bluetooth ni GPS que consultar.
Future<bool> Function() revisarPermisos = permisosListos;

/// Antes de entrar a la app, mientras falte algo: qué permisos necesita la
/// asistencia, para qué, y un botón que los pide todos. Así no salen los
/// diálogos del sistema en plena clase, con el llamado corriendo.
///
/// Sin ellos no se entra: sin Bluetooth ni ubicación no hay asistencia. La
/// cámara se pide al verificar el rostro, que es donde se usa.
class PermisosScreen extends StatefulWidget {
  final bool esEstudiante;

  /// A dónde ir cuando ya está todo.
  final WidgetBuilder siguiente;

  const PermisosScreen({
    super.key,
    required this.esEstudiante,
    required this.siguiente,
  });

  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen>
    with WidgetsBindingObserver {
  bool _listos = false;
  bool _pidiendo = false;

  /// Cambia para que la lista vuelva a leer el estado del celular.
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _revisar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema el permiso pudo cambiar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _revisar();
  }

  Future<void> _revisar() async {
    final listos = await revisarPermisos();
    if (!mounted) return;
    setState(() {
      _listos = listos;
      _revision++;
    });
  }

  Future<void> _permitir() async {
    setState(() => _pidiendo = true);
    await pedirPermisos();
    if (!mounted) return;
    setState(() => _pidiendo = false);
    await _revisar();
  }

  void _continuar() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: widget.siguiente),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String textoBoton;
    if (_pidiendo) {
      textoBoton = 'Pidiendo permisos...';
    } else if (_listos) {
      textoBoton = 'Continuar';
    } else {
      textoBoton = 'Permitir';
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFFC2C1FF),
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Permisos para la asistencia',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.esEstudiante
                  ? 'Tu celular se anuncia por Bluetooth al docente y la '
                      'ubicación comprueba que estés en el aula. Sin ellos no '
                      'puedes marcar asistencia. La cámara se pide al '
                      'verificar tu rostro.'
                  : 'Tu celular escucha por Bluetooth a los de la clase y la '
                      'ubicación comprueba que estés en el aula. Sin ellos no '
                      'se abre el radar.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            PermisosDelCelular(key: ValueKey(_revision)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _pidiendo
                    ? null
                    : _listos
                        ? _continuar
                        : _permitir,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E5CE6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  textoBoton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (!_listos && !_pidiendo) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: Geolocator.openAppSettings,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Si ya los negaste, actívalos en los ajustes del celular',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
