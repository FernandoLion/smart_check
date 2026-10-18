import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/verificacion_result_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../login_screen.dart';
import 'import_csv_screen.dart';

class TeacherSettingsScreen extends StatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  State<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends State<TeacherSettingsScreen>
    with SingleTickerProviderStateMixin {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceBg = Color(0xFF131315); // surface / background
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _onPrimary = Color(0xFF1800A7);
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _errorLight = Color(0xFFFFB4AB); // error
  static const Color _errorContainer = Color(0xFF93000A);

  // Estados interactivos del Radar y Notificaciones
  int _selectedRadarRange = 1; // 0: Cercano, 1: Medio, 2: Amplio
  bool _autoCloseList = true;
  bool _vibrateOnDetect = true;
  bool _remindBeforeClass = true;
  bool _summaryOnFinish = true;

  bool _isSyncing = false;
  String _syncTimestamp = 'Hace 5 min';
  late final AnimationController _syncController;

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  Future<void> _handleSyncNow() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncTimestamp = 'Sincronizando...';
    });
    _syncController.repeat();

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _syncController.stop();
    _syncController.reset();
    setState(() {
      _isSyncing = false;
      _syncTimestamp = 'Justo ahora';
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
            // 1. TOP STICKY BAR ("Configuracion" + Avatar)
            _buildTopAppBar(context),

            // 2. MAIN SCROLLABLE SETTINGS CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  // Header ("Configuración" + Badge "Sincronizado")
                  _buildHeaderSection(),
                  const SizedBox(height: 20),

                  // Profile Card del docente
                  _buildTeacherProfileCard(chairaData),
                  const SizedBox(height: 24),

                  // Section: CURSOS
                  _buildSectionTitle('CURSOS'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.school_outlined,
                      iconBgColor: _primaryIndigo.withValues(alpha: 0.2),
                      iconColor: _primaryLight,
                      title: 'Mis cursos',
                      trailingBadgeText: '4 cursos',
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.upload_file_outlined,
                      title: 'Importar estudiantes (CSV)',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ImportCsvScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.download_outlined,
                      title: 'Descargar plantilla CSV',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Descargando plantilla oficial Chairá...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section: RADAR DE ASISTENCIA
                  _buildSectionTitle('RADAR DE ASISTENCIA'),
                  _buildRadarSettingsCard(),
                  const SizedBox(height: 24),

                  // Section: PERMISOS DE LA APP
                  _buildSectionTitle('PERMISOS DE LA APP'),
                  _buildPermissionsCard(),
                  const SizedBox(height: 24),

                  // Section: APARIENCIA
                  _buildSectionTitle('APARIENCIA'),
                  _buildAppearanceCard(),
                  const SizedBox(height: 24),

                  // Section: NOTIFICACIONES
                  _buildSectionTitle('NOTIFICACIONES'),
                  _buildNotificationsCard(),
                  const SizedBox(height: 24),

                  // Section: DATOS
                  _buildSectionTitle('DATOS'),
                  _buildDataSectionCard(),
                  const SizedBox(height: 24),

                  // Section: CUENTA Y SEGURIDAD
                  _buildSectionTitle('CUENTA Y SEGURIDAD'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.lock_outline,
                      title: 'Cambiar contraseña',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.devices_outlined,
                      title: 'Cerrar sesión en otros dispositivos',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section: AYUDA
                  _buildSectionTitle('AYUDA'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.help_outline,
                      title: 'Centro de ayuda',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Reportar un problema',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.policy_outlined,
                      title: 'Términos y política de privacidad',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // Logout and Footer Section
                  _buildLogoutAndFooter(),
                ],
              ),
            ),

            // 3. BOTTOM NAVIGATION BAR (Cursos | Radar | Configuración)
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: _primaryLight,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Configuracion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
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
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Configuración',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(20),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Gestión de cuenta institucional y parámetros de aula',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherProfileCard(VerificacionResult? data) {
    final nombre = data?.nombre != null
        ? 'Prof. ${data!.nombre}'
        : 'Prof. Jhojan Fernando León Claros';
    // El correo real de la cuenta; deducirlo del nombre puede no coincidir.
    final email = context.read<AuthViewModel>().perfil?.email ??
        (data?.username != null
            ? '${data!.username}@udla.edu.co'
            : 'j.leon@udla.edu.co');
    final idText = data?.cedula != null ? 'ID #${data!.cedula}' : 'ID #88419';
    final fotoBytes = data?.imagenBytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  shape: BoxShape.circle,
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
                        size: 32,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _tertiaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surfaceElevated, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryIndigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Docente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      idText,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: _primaryLight,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Editar perfil',
                          style: TextStyle(
                            color: _primaryLight,
                            fontSize: 13,
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
        ],
      ),
    );
  }

  Widget _buildRadarSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Alcance de detección (BLE Micro-Zone)
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alcance de detección',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              Text(
                'BLE Micro-Zone',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildRangeSegment(0, 'Cercano'),
                _buildRangeSegment(1, 'Medio'),
                _buildRangeSegment(2, 'Amplio'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildFullWidthDivider(),
          const SizedBox(height: 14),

          // Duración del escaneo (10 min)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Duración del escaneo',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              Row(
                children: const [
                  Text(
                    '10 min',
                    style: TextStyle(color: _primaryLight, fontSize: 17),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFullWidthDivider(),
          const SizedBox(height: 14),

          // Tolerancia de llegada tarde (15 min)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tolerancia de llegada tarde',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              Row(
                children: const [
                  Text(
                    '15 min',
                    style: TextStyle(color: _primaryLight, fontSize: 17),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFullWidthDivider(),
          const SizedBox(height: 12),

          // Switch 1: Cerrar lista automáticamente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cerrar lista automáticamente',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bloquea registro al expirar el tiempo',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _autoCloseList,
                activeTrackColor: _primaryIndigo,
                onChanged: (val) => setState(() => _autoCloseList = val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFullWidthDivider(),
          const SizedBox(height: 12),

          // Switch 2: Vibrar al detectar estudiante
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vibrar al detectar estudiante',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Feedback háptico por check-in',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _vibrateOnDetect,
                activeTrackColor: _primaryIndigo,
                onChanged: (val) => setState(() => _vibrateOnDetect = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSegment(int index, String label) {
    final isSelected = _selectedRadarRange == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRadarRange = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _primaryIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return _buildGroupedCard([
      _buildPermissionItem(
        icon: Icons.bluetooth,
        iconColor: _primaryLight,
        title: 'Bluetooth',
        isGranted: true,
      ),
      _buildDivider(),
      _buildPermissionItem(
        icon: Icons.devices_other,
        iconColor: _primaryLight,
        title: 'Dispositivos cercanos',
        isGranted: true,
      ),
      _buildDivider(),
      _buildPermissionItem(
        icon: Icons.location_on_outlined,
        iconColor: _primaryLight,
        title: 'Ubicación',
        subtitle: 'Necesaria para escanear balizas Bluetooth',
        isGranted: true,
      ),
      _buildDivider(),
      _buildPermissionItem(
        icon: Icons.notifications_active_outlined,
        iconColor: _systemAmber,
        title: 'Notificaciones',
        isGranted: false,
      ),
    ]);
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool isGranted,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isGranted
                  ? _tertiaryContainer.withValues(alpha: 0.3)
                  : _systemAmber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGranted ? Icons.check : Icons.schedule,
                  color: isGranted ? _tertiaryGreen : _systemAmber,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isGranted ? 'Concedido' : 'Pendiente',
                  style: TextStyle(
                    color: isGranted ? _tertiaryGreen : _systemAmber,
                    fontSize: 12,
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

  Widget _buildAppearanceCard() {
    return _buildGroupedCard([
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _surfaceControl,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dark_mode_outlined,
                    color: _primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema actual',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    Text(
                      'Optimizado para OLED',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceControl,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: _primaryIndigo),
                  SizedBox(width: 6),
                  Text(
                    'Oscuro (Activo)',
                    style: TextStyle(color: Color(0xFFE4E2E4), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _buildDivider(),
      _buildNavRow(
        icon: Icons.translate,
        title: 'Idioma',
        trailingText: 'Español',
        onTap: () {},
      ),
    ]);
  }

  Widget _buildNotificationsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recordatorio antes de clase',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Aviso 10 minutos antes de iniciar',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _remindBeforeClass,
                activeTrackColor: _primaryIndigo,
                onChanged: (val) => setState(() => _remindBeforeClass = val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFullWidthDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen al finalizar',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Reporte automático de presentes y ausentes',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _summaryOnFinish,
                activeTrackColor: _primaryIndigo,
                onChanged: (val) => setState(() => _summaryOnFinish = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSectionCard() {
    return _buildGroupedCard([
      _buildNavRow(
        icon: Icons.file_download_outlined,
        title: 'Exportar historial de asistencia',
        subtitle: '(CSV / PDF)',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exportando historial docente...'),
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
              Row(
                children: [
                  RotationTransition(
                    turns: _syncController,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: _primaryLight,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sincronizar ahora',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _syncTimestamp,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
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
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildLogoutAndFooter() {
    return Column(
      children: [
        GestureDetector(
          onTap: _handleLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: _errorLight, size: 20),
                SizedBox(width: 8),
                Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: _errorLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Versión 1.0.0 • SmartCheck UDLA',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        const Text(
          'Universidad de la Amazonia • ID Campus 04',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Tab 1: Cursos -> Vuelve al Panel Docente Home (Pantalla 9)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, color: AppTheme.textSecondary, size: 24),
                SizedBox(height: 4),
                Text(
                  'Cursos',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Radar -> Próxima conexión con Flujo 4 (Pantalla 19 / 21)
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pronto conectaremos con el Flujo 4: Radar BLE en Vivo'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sensors, color: AppTheme.textSecondary, size: 24),
                SizedBox(height: 4),
                Text(
                  'Radar',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Tab 3: Configuración (Activo)
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, color: _primaryIndigo, size: 25),
              SizedBox(height: 4),
              Text(
                'Configuración',
                style: TextStyle(
                  color: _primaryIndigo,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
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
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildFullWidthDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    Color iconBgColor = _surfaceControl,
    Color iconColor = AppTheme.textSecondary,
    required String title,
    String? subtitle,
    String? trailingText,
    String? trailingBadgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: const TextStyle(
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingBadgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trailingBadgeText,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 17,
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
          ],
        ),
      ),
    );
  }
}