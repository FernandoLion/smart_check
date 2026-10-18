import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'teacher/teacher_home_screen.dart';
import '../models/usuario_perfil_model.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/app_theme.dart';
import '../utils/usuario_input_formatter.dart';
import 'recover_password_screen.dart';
import 'smart_register_screen.dart';
import 'student/student_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  int _segmentedControlGroupValue = 0; // 0 para Login, 1 para Registro

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos el ViewModel (MVVM)
    final authViewModel = context.watch<AuthViewModel>();

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
                  // Form conectado al ViewModel
                  _buildLoginForm(authViewModel.isLoading),
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
                color: AppTheme.surfaceElevated,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
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
                      AppTheme.primary.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.security,
                  size: 40,
                  color: AppTheme.primary,
                ),
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
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
                      ? const Color(0xFF39393b)
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

  Widget _buildLoginForm(bool isLoading) {
    return Column(
      children: [
        // Usuario institucional: el dominio @udla.edu.co es fijo, como en
        // Google con @gmail.com; solo se escribe "an.perez".
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          inputFormatters: [UsuarioInstitucionalFormatter()],
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'usuario',
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.badge_outlined,
              color: AppTheme.textSecondary,
              size: 22,
            ),
            suffixIcon: const _DominioFijo(),
            suffixIconConstraints: const BoxConstraints(minHeight: 48),
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
                color: AppTheme.primary.withValues(alpha: 0.4),
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
                color: AppTheme.primary.withValues(alpha: 0.4),
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
          onPressed: isLoading ? null : _handleLoginSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 8,
            shadowColor: AppTheme.primary.withValues(alpha: 0.5),
          ),
          child: isLoading
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
        Expanded(child: Divider(color: Color(0xFF353437), thickness: 1)),
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

  Future<void> _handleLoginSubmit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError('Por favor, ingresa tus datos de acceso.');
      return;
    }

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;

    if (!success) {
      _showError(authViewModel.errorMessage ?? 'Error al iniciar sesión');
      return;
    }

    // Cuenta creada antes de que se guardaran los perfiles: hay que
    // vincularla con su documento para conocer su rol.
    if (authViewModel.perfil == null) {
      final vinculado = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const _VincularDocumentoSheet(),
      );
      if (!mounted) return;
      if (vinculado != true) {
        await authViewModel.signOut();
        return;
      }
    }

    _entrarSegunRol(authViewModel.perfil!);
  }

  /// El rol sale del perfil guardado al registrarse, no de lo que elija el
  /// usuario. Solo se pregunta a los docentes que también cursan materias.
  void _entrarSegunRol(UsuarioPerfil perfil) {
    if (perfil.esDual) {
      _showRoleSelectionSheet();
    } else if (perfil.esDocente) {
      _navegarComo('Docente');
    } else if (perfil.esEstudiante) {
      _navegarComo('Estudiante');
    } else {
      context.read<AuthViewModel>().signOut();
      _showError('Tu cuenta no tiene un rol asignado. Contacta a soporte.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
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
        color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
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
            onTap: () {
              Navigator.pop(context);
              _navegarComo('Docente');
            },
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
                      color: AppTheme.primary.withValues(alpha: 0.2),
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
            onTap: () {
              Navigator.pop(context);
              _navegarComo('Estudiante');
            },
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
                      color: AppTheme.secondary.withValues(alpha: 0.2),
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
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthViewModel>().signOut();
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.surfaceControl.withValues(alpha: 0.6),
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

  void _navegarComo(String role) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sesión Iniciada como $role'),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'Estudiante'
            ? const StudentHomeScreen()
            : const TeacherHomeScreen(),
      ),
    );
  }
}

/// Sufijo fijo del campo de usuario, con el mismo estilo que en el registro.
class _DominioFijo extends StatelessWidget {
  const _DominioFijo();

  @override
  Widget build(BuildContext context) {
    // Sin `alignment`: el Container debe medir lo que mide el texto, no
    // expandirse a todo el ancho del campo.
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF353437),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        AuthViewModel.dominioInstitucional,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Pide el documento a una cuenta sin perfil y la vincula con Chairá.
class _VincularDocumentoSheet extends StatefulWidget {
  const _VincularDocumentoSheet();

  @override
  State<_VincularDocumentoSheet> createState() =>
      _VincularDocumentoSheetState();
}

class _VincularDocumentoSheetState extends State<_VincularDocumentoSheet> {
  final _docController = TextEditingController();

  @override
  void dispose() {
    _docController.dispose();
    super.dispose();
  }

  Future<void> _vincular() async {
    final documento = _docController.text.trim();
    if (documento.isEmpty) return;
    final authViewModel = context.read<AuthViewModel>();
    final ok = await authViewModel.vincularDocumento(documento);
    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final verificando = authViewModel.isVerifyingChaira;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verifica tu identidad',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tu cuenta aún no tiene un perfil. Ingresa tu documento para '
              'consultarlo en Chairá y asignar tu rol.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _docController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Nº de Documento',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.badge, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceControl,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (!verificando && authViewModel.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                authViewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: verificando ? null : _vincular,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: verificando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Verificar y continuar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
