import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/verificacion_result_model.dart';
import '../../services/identidad_facial_service.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/face_verification_viewmodel.dart';
import '../attendance/face_verification_screen.dart';
import '../login_screen.dart';
import 'attendance_detail_screen.dart';
import 'biometric_validation_screen.dart';
import '../../widgets/texto_sin_cortes.dart';

class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen>
    with SingleTickerProviderStateMixin {
  // Colores exactos del HTML de Stitch
  static const Color _surfaceBg = Color(0xFF131315); // surface / background
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _onPrimary = Color(0xFF1800A7);
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);

  // Estados de los Switches y Micro-interacciones
  bool _autoBeacon = true;
  bool _batterySaver = false;
  bool _classReminder = true;
  bool _attendanceSummary = true;

  bool _isCopied = false;
  bool _isSyncing = false;
  String _lastSyncText = 'Hace 5 min';

  late final AnimationController _syncController;

  /// Si este celular ya guarda la cara del estudiante. null mientras se
  /// consulta.
  bool? _tieneRostro;

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mirarRostro();
  }

  Future<void> _mirarRostro() async {
    final uid = context.read<AuthViewModel>().perfil?.uid;
    final tiene = uid != null && await IdentidadEnCelular.tieneReferencia(uid);
    if (mounted) setState(() => _tieneRostro = tiene);
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  /// El celular que esta cuenta tiene vinculado, o un guion si todavia no
  /// hay ninguno. Es el mismo que comprueba el servidor al firmar la
  /// asistencia, no un identificador de adorno.
  String get _idDelDispositivo =>
      context.read<AuthViewModel>().dispositivoVinculado ?? 'sin vincular';

  Future<void> _handleCopyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: _idDelDispositivo));
    if (!mounted) return;
    setState(() => _isCopied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _handleSyncNow() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _lastSyncText = 'Sincronizando...';
    });
    _syncController.repeat();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    _syncController.stop();
    _syncController.reset();
    setState(() {
      _isSyncing = false;
      _lastSyncText = 'Hace un momento';
    });
  }

  Future<void> _handleLogout() async {
    final authVM = context.read<AuthViewModel>();
    await authVM.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final VerificacionResult? chairaData = authVM.usuarioActual;

    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // TOP STICKY BAR ("Configuración" + Shield + User Avatar)
            _buildTopAppBar(context),

            // MAIN SCROLLABLE SETTINGS CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  // 1. Encabezado principal + Badge "Sincronizado"
                  _buildMainHeader(),
                  const SizedBox(height: 16),

                  // 2. Tarjeta de perfil del estudiante
                  _buildStudentProfileCard(chairaData),
                  const SizedBox(height: 24),

                  // 3. Sección "MIS CURSOS"
                  _buildSectionTitle('MIS CURSOS'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.auto_stories_outlined,
                      title: 'Cursos inscritos',
                      trailingWidget: _buildPillBadge(
                        text: '5 asignaturas',
                        bgColor: _surfaceControl,
                        textColor: AppTheme.textSecondary,
                      ),
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.calendar_today_outlined,
                      title: 'Historial de asistencia',
                      trailingText: '92% global',
                      trailingTextColor: _tertiaryGreen,
                      trailingTextBold: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceDetailScreen(),
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 4. Sección "BALIZA"
                  _buildSectionTitle('BALIZA'),
                  _buildGroupedCard([
                    // Estado de la baliza
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _buildIconBox(Icons.podcasts),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    'Estado de la baliza',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _tertiaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 4,
                                  backgroundColor: _tertiaryGreen,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Activa',
                                  style: TextStyle(
                                    color: _tertiaryGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),

                    // ID de mi dispositivo + Botón Copiar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _buildIconBox(Icons.badge_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Celular vinculado',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: $_idDelDispositivo',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _handleCopyDeviceId,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceControl,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCopied
                                        ? Icons.check
                                        : Icons.content_copy,
                                    color: _primaryLight,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isCopied ? '¡Copiado!' : 'Copiar',
                                    style: const TextStyle(
                                      color: _primaryLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),

                    // Activar baliza automáticamente
                    _buildSwitchRow(
                      icon: Icons.schedule,
                      title: 'Activar baliza automáticamente',
                      subtitle: 'En horario programado de clase según geocerca',
                      value: _autoBeacon,
                      onChanged: (val) => setState(() => _autoBeacon = val),
                    ),
                    _buildDivider(),

                    // Modo ahorro de batería
                    _buildSwitchRow(
                      icon: Icons.battery_saver,
                      title: 'Modo ahorro de batería',
                      subtitle: 'Reduce la frecuencia de emisión de baliza',
                      value: _batterySaver,
                      onChanged: (val) => setState(() => _batterySaver = val),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 5. Sección "PERMISOS DE LA APP"
                  _buildSectionTitle('PERMISOS DE LA APP'),
                  _buildGroupedCard([
                    _buildPermissionRow(
                      icon: Icons.bluetooth,
                      title: 'Bluetooth',
                      isGranted: true,
                    ),
                    _buildDivider(),
                    _buildPermissionRow(
                      icon: Icons.sensors,
                      title: 'Dispositivos cercanos',
                      isGranted: true,
                    ),
                    _buildDivider(),
                    _buildPermissionRow(
                      icon: Icons.near_me_outlined,
                      title: 'Ubicación',
                      subtitle: 'Necesaria para escanear balizas Bluetooth',
                      isGranted: true,
                    ),
                    _buildDivider(),
                    _buildPermissionRow(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notificaciones',
                      isGranted: false,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 6. Sección "APARIENCIA"
                  _buildSectionTitle('APARIENCIA'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.language,
                      title: 'Idioma',
                      trailingText: 'Español',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildIconBox(
                            Icons.light_mode_outlined,
                            iconColor: _systemAmber,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tema actual',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Modo Claro (Activo)',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 7. Sección "NOTIFICACIONES"
                  _buildSectionTitle('NOTIFICACIONES'),
                  _buildGroupedCard([
                    _buildSwitchRow(
                      icon: Icons.alarm,
                      title: 'Recordatorio antes de clase',
                      subtitle: '15 min antes del inicio',
                      value: _classReminder,
                      onChanged: (val) => setState(() => _classReminder = val),
                    ),
                    _buildDivider(),
                    _buildSwitchRow(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Resumen de asistencia al finalizar',
                      subtitle: 'Notificación con estado de la sesión',
                      value: _attendanceSummary,
                      onChanged: (val) =>
                          setState(() => _attendanceSummary = val),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 8. Sección "DATOS"
                  _buildSectionTitle('DATOS'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.file_download_outlined,
                      title: 'Exportar historial de asistencia',
                      subtitle: 'Reporte en PDF o CSV de inasistencias',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Generando reporte de asistencia...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    InkWell(
                      onTap: _handleSyncNow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  RotationTransition(
                                    turns: _syncController,
                                    child: _buildIconBox(Icons.sync),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextoSinCortes(
                                          'Sincronizar ahora',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        TextoSinCortes(
                                          'Última sincronización',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _lastSyncText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.refresh,
                                    color: AppTheme.textTertiary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 9. Sección "CUENTA Y SEGURIDAD"
                  _buildSectionTitle('CUENTA Y SEGURIDAD'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.lock_reset,
                      title: 'Cambiar contraseña',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.devices,
                      title: 'Cerrar sesión en otros dispositivos',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.face_outlined,
                      title: _tieneRostro == true
                          ? 'Probar mi rostro'
                          : 'Registrar mi rostro',
                      subtitle: _tieneRostro == true
                          ? 'Se compara con el que guarda este celular'
                          : 'Se compara con tu foto de Chairá',
                      onTap: _probarRostro,
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.face_retouching_off,
                      title: 'Borrar mi rostro de este celular',
                      subtitle: 'Se volverá a comparar con tu foto de Chairá',
                      onTap: _borrarRostro,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 10. Sección "AYUDA"
                  _buildSectionTitle('AYUDA'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.help_center_outlined,
                      title: 'Centro de ayuda',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.feedback_outlined,
                      title: 'Reportar un problema',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.security_outlined,
                      title: 'Términos y política de privacidad',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // 11. Pie de pantalla: Botón "Cerrar sesión" + Versión
                  _buildLogoutFooter(),
                ],
              ),
            ),

            // BOTTOM NAVIGATION BAR (Cursos | Radar | Configuración)
            _buildBottomNavigationBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceBg.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: _primaryLight,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Configuración',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFC7C4D7),
                  size: 22,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: _onPrimary,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextoSinCortes(
                'Configuración',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Parámetros de cuenta, baliza y privacidad',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 4, backgroundColor: _tertiaryGreen),
              SizedBox(width: 6),
              Text(
                'Sincronizado',
                style: TextStyle(
                  color: _tertiaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentProfileCard(VerificacionResult? data) {
    final nombre = data?.nombre ?? 'Carlos Andrés Muñoz Rivera';
    // El correo real de la cuenta; deducirlo del nombre puede no coincidir.
    final email =
        context.read<AuthViewModel>().perfil?.email ??
        (data?.username != null
            ? '${data!.username}@udla.edu.co'
            : 'c.munoz@udla.edu.co');
    final idInfo = data?.cedula != null
        ? 'ID #${data!.cedula} • Semestre VI'
        : 'ID #2022-3810 • Semestre VI';
    final fotoBytes = data?.imagenBytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surfaceControl, width: 2),
                      image: fotoBytes != null
                          ? DecorationImage(
                              image: MemoryImage(fotoBytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: fotoBytes == null
                        ? const Icon(
                            Icons.person,
                            color: AppTheme.textSecondary,
                            size: 30,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _tertiaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surfaceElevated, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryLight.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                color: _primaryLight,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Estudiante',
                                style: TextStyle(
                                  color: _primaryLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          idInfo,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, color: _primaryLight, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Editar perfil',
                      style: TextStyle(
                        color: _primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildIconBox(IconData icon, {Color iconColor = _primaryLight}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildPillBadge({
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Registra la cara del estudiante en este celular, o comprueba la que ya
  /// tiene, sin esperar a un llamado: así llega a clase enrolado y no gasta
  /// la ventana de diez minutos en eso.
  Future<void> _probarRostro() async {
    final messenger = ScaffoldMessenger.of(context);
    final rostro = await verificarRostro(context);
    if (!mounted) return;
    await _mirarRostro();
    if (rostro == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          rostro.resultado == ResultadoIdentidad.enrolado
              ? 'Listo: tu rostro quedó registrado en este celular.'
              : 'Listo: eres tú.',
        ),
      ),
    );
  }

  /// Borra la huella numérica del rostro guardada en este celular. La
  /// próxima vez que marque asistencia se volverá a registrar contra Chairá.
  Future<void> _borrarRostro() async {
    final uid = context.read<AuthViewModel>().perfil?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!await IdentidadEnCelular.tieneReferencia(uid)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay un rostro tuyo en este celular.')),
      );
      return;
    }
    if (!mounted) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          '¿Borrar tu rostro?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'La próxima vez que marques asistencia tendrás que registrarlo de '
          'nuevo, comparándolo con tu foto de Chairá.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogo, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirma != true) return;
    await IdentidadEnCelular.olvidar(uid);
    await _mirarRostro();
    messenger.showSnackBar(
      const SnackBar(content: Text('Tu rostro se borró de este celular.')),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Color trailingTextColor = AppTheme.textSecondary,
    bool trailingTextBold = false,
    Widget? trailingWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        // El lado derecho ocupa lo que necesita, hasta el 45% del ancho; el
        // resto es para el título.
        child: LayoutBuilder(
          builder: (context, caja) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildIconBox(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextoSinCortes(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: caja.maxWidth * 0.45),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trailingWidget != null) Flexible(child: trailingWidget),
                    if (trailingText != null)
                      Flexible(
                        child: Text(
                          trailingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: trailingTextColor,
                            fontSize: 13,
                            fontWeight: trailingTextBold
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                _buildIconBox(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextoSinCortes(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            activeTrackColor: _primaryIndigo,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isGranted,
  }) {
    final badgeColor = isGranted ? _tertiaryGreen : _systemAmber;
    final badgeText = isGranted ? 'Concedido' : 'Pendiente';
    final badgeIcon = isGranted
        ? Icons.check_circle_outline
        : Icons.pending_outlined;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 15),
          const SizedBox(width: 5),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      // Con poco ancho (pantalla angosta o letra grande) la etiqueta baja
      // debajo del título, para que el título no quede apretado.
      child: LayoutBuilder(
        builder: (context, caja) {
          final etiquetaAbajo =
              caja.maxWidth < MediaQuery.textScalerOf(context).scale(300);
          return Row(
            children: [
              _buildIconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextoSinCortes(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (etiquetaAbajo) ...[const SizedBox(height: 6), badge],
                  ],
                ),
              ),
              if (!etiquetaAbajo) ...[const SizedBox(width: 8), badge],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogoutFooter() {
    return Column(
      children: [
        GestureDetector(
          onTap: _handleLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _surfaceElevated,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: _systemRed, size: 22),
                SizedBox(width: 8),
                Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: _systemRed,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Versión 1.0.0 • SmartCheck UDLA Estudiantes',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: BoxDecoration(
        color: _surfaceBg.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Tab 1: Cursos -> Vuelve al Portal Estudiante Home (Pantalla 5)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, color: Color(0xFFC7C4D7), size: 24),
                SizedBox(height: 4),
                Text(
                  'Cursos',
                  style: TextStyle(
                    color: Color(0xFFC7C4D7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Radar -> Abre Validación Biométrica / Radar (Pantalla 6)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BiometricValidationScreen(),
                ),
              );
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar, color: Color(0xFFC7C4D7), size: 24),
                SizedBox(height: 4),
                Text(
                  'Radar',
                  style: TextStyle(
                    color: Color(0xFFC7C4D7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Tab 3: Configuración (Activo)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: _primaryIndigo.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 4),
              const TextoSinCortes(
                'Configuración',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
