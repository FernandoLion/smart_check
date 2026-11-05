import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usuario_perfil_model.dart';
import '../utils/app_theme.dart';
import '../utils/usuario_input_formatter.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'home_screen.dart';

/// Vista (la V de MVVM) del inicio de sesión.
///
/// Es un StatefulWidget porque guarda estado propio de la pantalla: lo que
/// se escribe en los campos, si la contraseña se ve o no, y si todavía se
/// está mirando la sesión guardada.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  /// Mientras se mira si ya hay una sesión guardada en este celular.
  bool _restaurando = true;

  @override
  void initState() {
    super.initState();
    // Se espera al primer frame para poder usar el context con Provider.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restaurar());
  }

  /// Quien ya entró en este celular no vuelve a escribir la contraseña.
  Future<void> _restaurar() async {
    final auth = context.read<AuthViewModel>();
    var entro = false;
    try {
      entro = await auth.restaurarSesion();
    } catch (_) {
      // Sin red o sin Firebase: se pide el ingreso como siempre.
    }
    if (!mounted) return;
    if (entro) {
      _entrarSegunRol(auth.perfil!);
    }
    setState(() => _restaurando = false);
  }

  @override
  void dispose() {
    // Los controladores reservan memoria: se liberan al cerrar la pantalla.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // watch: escucha el ViewModel y redibuja cuando llama notifyListeners().
    final authViewModel = context.watch<AuthViewModel>();
    if (_restaurando) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Brillo de fondo detrás del logo.
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
                  _buildHeaderBranding(),
                  const SizedBox(height: 32),
                  // El formulario recibe del ViewModel si está cargando.
                  _buildLoginForm(authViewModel.isLoading),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logo, nombre de la app y subtítulo.
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

  /// Campo de usuario, campo de contraseña y botón de entrar.
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
        // Contraseña, con el ojo para mostrarla u ocultarla.
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
        const SizedBox(height: 24),
        // Botón principal. Mientras carga queda deshabilitado (onPressed
        // null) y muestra un spinner: así no se envía dos veces.
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

  /// Lo que pasa al tocar "Iniciar Sesión".
  Future<void> _handleLoginSubmit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError('Por favor, ingresa tus datos de acceso.');
      return;
    }

    // read (y no watch): aquí solo se llama a un método, no se escucha.
    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    // Durante el await la pantalla pudo cerrarse.
    if (!mounted) return;

    if (!success) {
      _showError(authViewModel.errorMessage ?? 'Error al iniciar sesión');
      return;
    }

    _entrarSegunRol(authViewModel.perfil!);
  }

  /// El rol sale del perfil guardado en Firestore, no de lo que elija el
  /// usuario. Solo se pregunta a los docentes que también cursan materias.
  void _entrarSegunRol(UsuarioPerfil perfil) {
    if (perfil.esDual) {
      _showRoleSelectionSheet();
    } else if (perfil.esDocente) {
      _navegarComo(Rol.docente);
    } else if (perfil.esEstudiante) {
      _navegarComo(Rol.estudiante);
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

  /// Hoja inferior para el docente que también es estudiante.
  void _showRoleSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.only(
          top: 12,
          left: 16,
          right: 16,
          bottom: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // La "manija" gris de arriba de la hoja.
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
              'Se detectó perfil dual Docente/Estudiante para esta cuenta '
              'institucional.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            _OpcionRol(
              icono: Icons.school,
              color: AppTheme.primary,
              titulo: 'Modo Docente (Gestionar Clases)',
              subtitulo: 'Acceso a control de asistencia y aulas',
              onTap: () {
                Navigator.pop(sheetContext);
                _navegarComo(Rol.docente);
              },
            ),
            const SizedBox(height: 10),
            _OpcionRol(
              icono: Icons.badge,
              color: AppTheme.secondary,
              titulo: 'Modo Estudiante (Asistencia)',
              subtitulo: 'Marcación de carné y portal de alumno',
              onTap: () {
                Navigator.pop(sheetContext);
                _navegarComo(Rol.estudiante);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.read<AuthViewModel>().signOut();
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.surfaceControl.withValues(
                  alpha: 0.6,
                ),
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
      ),
    );
  }

  /// Avisa con qué rol entró y reemplaza el login por la pantalla de inicio
  /// (pushReplacement: con "atrás" no se vuelve al login).
  void _navegarComo(String rol) {
    final nombreRol = rol == Rol.docente ? 'Docente' : 'Estudiante';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sesión Iniciada como $nombreRol'),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(rol: rol)),
    );
  }
}

/// Sufijo fijo "@udla.edu.co" dentro del campo de usuario.
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

/// Una tarjeta de la hoja de elegir perfil (Docente o Estudiante).
class _OpcionRol extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionRol({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
