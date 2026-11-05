import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verificacion_result_model.dart';
import '../utils/app_theme.dart';
import '../utils/usuario_input_formatter.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/selector_ingreso.dart';
import 'login_screen.dart';

/// Vista del registro, en dos pasos:
///
/// 1. **Validación de identidad**: se escribe la cédula y se consulta en
///    Chairá. Si existe, aparece la tarjeta con nombre, programa y foto, y
///    Chairá dice si es docente o estudiante.
/// 2. **Credenciales**: el usuario institucional (lo propone Chairá) y la
///    contraseña. Al crear la cuenta se guarda el perfil con el rol.
class SmartRegisterScreen extends StatefulWidget {
  const SmartRegisterScreen({super.key});

  @override
  State<SmartRegisterScreen> createState() => _SmartRegisterScreenState();
}

class _SmartRegisterScreenState extends State<SmartRegisterScreen> {
  final _docController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  // Apagado por defecto: un docente solo es también estudiante si lo activa.
  bool _alsoStudent = false;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    // Se limpia cualquier verificación o error anterior al entrar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().clearState();
    });
  }

  @override
  void dispose() {
    _docController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Fuerza de 0 a 3: un punto por largo (8+), uno por mayúscula y uno por
  /// número o símbolo. Solo pinta las barritas; quien decide si se acepta es
  /// Firebase (pide al menos 6 caracteres).
  void _checkPasswordStrength(String pass) {
    int strength = 0;
    if (pass.length >= 8) strength++;
    if (pass.contains(RegExp(r'[A-Z]'))) strength++;
    if (pass.contains(RegExp(r'[0-9!@#\$&*~]'))) strength++;
    setState(() => _passwordStrength = strength);
  }

  /// Botón "Verificar" del paso 1.
  Future<void> _verificarDocumento() async {
    final documento = _docController.text.trim();
    if (documento.isEmpty) {
      _showError('Ingresa un número de documento.');
      return;
    }

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.verificarEnChaira(documento);
    if (!mounted) return;

    if (success && authViewModel.verificacionResult != null) {
      // Se llena el usuario con el que Chairá tiene para esa persona.
      _emailController.text =
          authViewModel.verificacionResult!.username ?? documento;
    } else {
      _showError(
        authViewModel.errorMessage ??
            'No se encontraron datos para este documento.',
      );
    }
  }

  /// Botón "Crear cuenta" del paso 2.
  Future<void> _handleRegister() async {
    final authViewModel = context.read<AuthViewModel>();
    final result = authViewModel.verificacionResult;

    if (result == null || !result.success) {
      _showError('Primero debes verificar tu documento en el Paso 1.');
      return;
    }

    final usernameInput = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (usernameInput.isEmpty || password.isEmpty) {
      _showError('Completa tu usuario institucional y contraseña.');
      return;
    }

    // El dominio @udla.edu.co es fijo: el ViewModel lo agrega y valida.
    final success = await authViewModel.register(
      usernameInput,
      password,
      tambienEstudiante: result.esDocente && _alsoStudent,
    );
    if (!mounted) return;
    if (!success) {
      _showError(authViewModel.errorMessage ?? 'Error al registrar la cuenta.');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta creada.'),
        backgroundColor: AppTheme.success,
      ),
    );
    // La cuenta nueva ya tiene la sesión iniciada: al volver al login, este
    // la encuentra (sesión guardada) y entra directo según el rol.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final result = authViewModel.verificacionResult;
    final isVerified = result != null && result.success;
    final verificationError = (result != null && !result.success)
        ? result.error
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: 24),
            const SelectorIngreso(enRegistro: true),
            const SizedBox(height: 24),
            // PASO 1
            _buildStepTitle(
              'PASO 1: VALIDACIÓN DE IDENTIDAD',
              trailing: isVerified ? _buildSyncBadge() : null,
            ),
            const SizedBox(height: 8),
            _buildSearchBox(authViewModel.isVerifyingChaira),
            if (verificationError != null) ...[
              const SizedBox(height: 8),
              _buildVerificationError(verificationError),
            ],
            // La tarjeta aparece cuando Chairá encontró a la persona.
            if (isVerified) ...[
              const SizedBox(height: 16),
              _buildDigitalIDCard(result),
              const SizedBox(height: 16),
              if (result.esDocente) _buildTeacherToggle(),
            ],
            const SizedBox(height: 24),
            // PASO 2
            _buildStepTitle('PASO 2: CREACIÓN DE CREDENCIALES'),
            const SizedBox(height: 16),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 32),
            _buildRegisterButton(authViewModel.isLoading),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppTheme.primary.withValues(alpha: 0.3),
                AppTheme.success.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: const Icon(
            Icons.verified_user,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SmartCheck',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Registro Inteligente Institucional',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStepTitle(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  /// Puntito verde "Sincronizado" cuando Chairá ya respondió.
  Widget _buildSyncBadge() {
    return const Row(
      children: [
        Icon(Icons.circle, color: AppTheme.success, size: 6),
        SizedBox(width: 4),
        Text(
          'Sincronizado',
          style: TextStyle(
            color: AppTheme.success,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Campo de cédula con el botón "Verificar".
  Widget _buildSearchBox(bool isVerifying) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.only(left: 12, right: 6),
      child: Row(
        children: [
          const Icon(Icons.badge, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _docController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Nº de Documento / Carné',
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: isVerifying ? null : _verificarDocumento,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Verificar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationError(String mensaje) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta con lo que respondió Chairá: foto, tipo, documento, nombre y
  /// programa.
  Widget _buildDigitalIDCard(VerificacionResult data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surfaceElevated, Color(0xFF1f1f21)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
        border: Border.all(color: AppTheme.success, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AppTheme.success, size: 14),
                SizedBox(width: 4),
                Text(
                  'VERIFICADO EN SISTEMA',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La foto de Chairá; si no llegó, un ícono de persona.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceControl,
                  borderRadius: BorderRadius.circular(12),
                  image: data.imagenBytes != null
                      ? DecorationImage(
                          image: MemoryImage(data.imagenBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: data.imagenBytes == null
                    ? const Icon(
                        Icons.person,
                        color: AppTheme.textSecondary,
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data.tipoUsuario ?? 'Estudiante',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'ID: ${data.cedula ?? data.documentoConsultado}',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.nombre ?? 'Sin nombre',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      data.programa ?? 'Sin programa',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Solo para docentes: "También curso materias" les da el rol dual.
  Widget _buildTeacherToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_library,
            color: AppTheme.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'También curso materias',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Habilita rol dual de Estudiante',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: _alsoStudent,
            activeTrackColor: AppTheme.success,
            onChanged: (val) => setState(() => _alsoStudent = val),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    // Cuando Chairá da el usuario, el correo no se discute: se muestra tal
    // cual y no se deja editar. Si no lo dio, se deduce del nombre y la
    // persona puede corregirlo.
    final verificado =
        context.watch<AuthViewModel>().verificacionResult?.correoVerificado ??
        false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            verificado
                ? 'Correo Institucional (verificado en Chairá)'
                : 'Correo Institucional Asignado',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.surfaceControl,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  readOnly: verificado,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [UsuarioInstitucionalFormatter()],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'usuario',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF353437),
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(14),
                  ),
                ),
                child: const Text(
                  AuthViewModel.dominioInstitucional,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'Crear Contraseña única',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.surfaceControl,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.only(left: 16, right: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: _checkPasswordStrength,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      letterSpacing: 0,
                    ),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Medidor de fuerza: tres barritas que se pintan de verde.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              for (var nivel = 1; nivel <= 3; nivel++) ...[
                if (nivel > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _passwordStrength >= nivel
                          ? AppTheme.success
                          : AppTheme.surfaceControl,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : _handleRegister,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: AppTheme.primary.withValues(alpha: 0.25),
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
                Icon(Icons.person_add, size: 22),
                SizedBox(width: 8),
                Text(
                  'CREAR CUENTA',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
    );
  }
}
