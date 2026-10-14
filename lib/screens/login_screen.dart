import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:ui';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'recover_password_screen.dart';
import 'smart_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _segmentedControlGroupValue = 0; // 0 para Login, 1 para Registro

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // bg-surface-oled
      body: Stack(
        children: [
          // Dynamic Background Glow
          Positioned(
            top: -64,
            left: MediaQuery.of(context).size.width / 2 - 144,
            child: Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Header Branding
                  _buildHeaderBranding(),
                  const SizedBox(height: 24),

                  // Segmented Control
                  _buildSegmentedControl(),
                  const SizedBox(height: 24),

                  // Form
                  _buildLoginForm(),
                  const SizedBox(height: 12),

                  // Divider
                  _buildDivider(),
                  const SizedBox(height: 12),

                  // Magic Link Button
                  _buildMagicLinkButton(),
                  const SizedBox(height: 24),

                  // Quick Biometric Hint
                  _buildBiometricHint(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBranding() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated, // surface-container-high
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primary.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.security,
                  size: 40,
                  color: AppTheme.primary,
                ), // shield_lock
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.success, // tertiary-container
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'SmartCheck',
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Acceso Universitario Inteligente',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _segmentedControlGroupValue = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _segmentedControlGroupValue == 0
                      ? const Color(0xFF39393b) // surface-bright
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _segmentedControlGroupValue == 0
                      ? [
                          const BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _segmentedControlGroupValue == 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _segmentedControlGroupValue == 0
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Navegar directo a la pantalla de registro
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SmartRegisterScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _segmentedControlGroupValue == 1
                      ? const Color(0xFF39393b)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Registrarse',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Input Documento/Email
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Número de Documento o usuario@udla.edu.co',
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.badge_outlined,
              color: AppTheme.textSecondary,
              size: 22,
            ),
            filled: true,
            fillColor: AppTheme.surfaceControl,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppTheme.primary.withOpacity(0.4),
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Contraseña
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Contraseña única',
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppTheme.textSecondary,
              size: 22,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: AppTheme.surfaceControl,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppTheme.primary.withOpacity(0.4),
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Olvidé contraseña
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecoverPasswordScreen(),
                ),
              );
            },
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(color: AppTheme.secondary, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Botón Iniciar Sesión Principal
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLoginSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 8,
            shadowColor: AppTheme.primary.withOpacity(0.5),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(
          child: Divider(color: Color(0xFF353437), thickness: 1),
        ), // surface-variant
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            'O INGRESA SIN CONTRASEÑA',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFF353437), thickness: 1)),
      ],
    );
  }

  Widget _buildMagicLinkButton() {
    return TextButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviando Magic Link al correo...')),
        );
      },
      style: TextButton.styleFrom(
        backgroundColor: AppTheme.surfaceControl,
        foregroundColor: AppTheme.primary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Icon(Icons.auto_awesome, size: 20),
          Text('Enviar Magic Link al correo', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBiometricHint() {
    return const Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Icon(
          Icons.contactless_outlined,
          color: AppTheme.textTertiary,
          size: 16,
        ),
        Text(
          'Compatible con Apple Face ID y NFC Campus Key',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  void _handleLoginSubmit() {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa tus datos de acceso.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Según el diseño de Stitch, aquí se abre el BottomSheet para seleccionar el Rol (Docente o Estudiante)
    _showRoleSelectionSheet();
  }

  void _showRoleSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _buildRoleBottomSheet();
      },
    );
  }

  Widget _buildRoleBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Con qué perfil deseas ingresar hoy?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Se detectó perfil dual Docente/Estudiante para esta cuenta institucional.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // Opción Docente
          GestureDetector(
            onTap: () => _performFirebaseLogin('Docente'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF353437),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Modo Docente (Gestionar Clases)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                        Text(
                          'Acceso a control de asistencia y aulas',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Opción Estudiante
          GestureDetector(
            onTap: () => _performFirebaseLogin('Estudiante'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceControl,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge,
                      color: AppTheme.secondary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Modo Estudiante (Asistencia)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                        Text(
                          'Marcación de carné y portal de alumno',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.surfaceControl.withOpacity(0.6),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: AppTheme.error,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performFirebaseLogin(String role) async {
    Navigator.pop(context); // Cierra el BottomSheet
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signInWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión Iniciada como $role'),
          backgroundColor: AppTheme.success,
        ),
      );
      // Aquí navegaremos al Home correspondiente según el rol elegido
    }
  }
}
