import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/curso_model.dart';
import '../../models/inscrito_model.dart';
import '../../models/sesion_model.dart';
import '../../models/verificacion_result_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/cerrar_sesion.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/teacher_viewmodel.dart';
import '../login_screen.dart';
import '../../widgets/ajustes_compartidos.dart';
import '../../widgets/botones_accesibles.dart';
import 'import_csv_screen.dart';

class TeacherSettingsScreen extends StatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  State<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends State<TeacherSettingsScreen> {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceBg = Color(0xFF131315); // surface / background
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _onPrimary = Color(0xFF1800A7);
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _errorLight = Color(0xFFFFB4AB); // error
  static const Color _errorContainer = Color(0xFF93000A);

  static String _cursos(int n) => n == 1 ? '1 curso' : '$n cursos';

  /// La lista pegada va a un curso: primero se elige cuál, y al confirmar
  /// quedan inscritos en él.
  Future<void> _importarEstudiantes() async {
    final teacherVM = context.read<TeacherViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final cursos = teacherVM.cursos.where((c) => !c.archivado).toList();
    if (cursos.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Primero crea un curso para inscribir estudiantes.'),
        ),
      );
      return;
    }
    final curso = cursos.length == 1
        ? cursos.single
        : await showModalBottomSheet<Curso>(
            context: context,
            backgroundColor: _surfaceElevated,
            builder: (hoja) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '¿A qué curso?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final c in cursos)
                    ListTile(
                      title: Text(
                        c.nombre,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [c.codigo, if (c.grupo.isNotEmpty) 'Grupo ${c.grupo}']
                            .join(' • '),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () => Navigator.pop(hoja, c),
                    ),
                ],
              ),
            ),
          );
    if (curso == null || !mounted) return;
    final nuevos = await Navigator.push<List<Inscrito>>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportCsvScreen(courseName: curso.nombre),
      ),
    );
    if (nuevos == null || nuevos.isEmpty) return;
    final listo = await teacherVM.inscribir(curso.id, nuevos);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          listo
              ? '${nuevos.length} inscritos en ${curso.nombre}.'
              : teacherVM.error ?? 'No se pudieron inscribir.',
        ),
        backgroundColor: listo ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Future<void> _handleLogout() async {
    await cerrarSesion(context);

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
                      trailingBadgeText: _cursos(
                        context.watch<TeacherViewModel>().cursos.length,
                      ),
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.upload_file_outlined,
                      title: 'Importar estudiantes',
                      subtitle: 'Eliges el curso y el Excel o CSV de la '
                          'lista',
                      onTap: _importarEstudiantes,
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.content_copy_outlined,
                      title: 'Copiar plantilla CSV',
                      subtitle: 'Los títulos que entiende la importación; '
                          'la lista que exporta Chairá también sirve',
                      onTap: _copiarPlantilla,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section: RADAR DE ASISTENCIA (las reglas, no preferencias)
                  _buildSectionTitle('RADAR DE ASISTENCIA'),
                  _buildRadarInfoCard(),
                  const SizedBox(height: 24),

                  // Section: PERMISOS DE LA APP (leídos del celular)
                  _buildSectionTitle('PERMISOS DE LA APP'),
                  const PermisosDelCelular(),
                  const SizedBox(height: 24),

                  // Section: CUENTA Y SEGURIDAD
                  _buildSectionTitle('CUENTA Y SEGURIDAD'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.lock_outline,
                      title: 'Cambiar contraseña',
                      subtitle: 'Te llega un enlace a tu correo institucional',
                      onTap: () => pedirCambioDeContrasena(context),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Section: AYUDA
                  _buildSectionTitle('AYUDA'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.help_outline,
                      title: 'Cómo pasar lista',
                      onTap: () => mostrarAyuda(context, docente: true),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.policy_outlined,
                      title: 'Datos y privacidad de los estudiantes',
                      onTap: () => mostrarPrivacidad(context),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // Logout and Footer Section
                  _buildLogoutAndFooter(),
                ],
              ),
            ),
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
          Tocable(
            onTap: () => Navigator.pop(context),
            nombre: 'Volver',
            alineacion: AlignmentDirectional.centerStart,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new,
                  color: _primaryLight,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Configuración',
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
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Configuración',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Gestión de cuenta institucional y parámetros de aula',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildTeacherProfileCard(VerificacionResult? data) {
    final nombre = data?.nombre != null ? 'Prof. ${data!.nombre}' : '—';
    // El correo real de la cuenta; deducirlo del nombre puede no coincidir.
    final email = context.read<AuthViewModel>().perfil?.email ?? '';
    final idText = data?.cedula != null ? 'Doc. ${data!.cedula}' : '';
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        idText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
                const SizedBox(height: 8),
                const Text(
                  'Tus datos vienen de Chairá.',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cómo funciona el radar. No son preferencias: son las reglas que cumple
  /// la app y que el servidor vuelve a comprobar.
  Widget _buildRadarInfoCard() {
    return _buildGroupedCard([
      _buildInfoRow(
        Icons.timer_outlined,
        'Duración del llamado',
        '${Sesion.minutosLlamado} min',
      ),
      _buildDivider(),
      _buildInfoRow(Icons.lock_clock_outlined, 'Cierre', 'Solo, al vencer'),
      _buildDivider(),
      _buildInfoRow(
        Icons.event_available_outlined,
        'Se abre',
        'En el horario del curso',
      ),
      _buildDivider(),
      _buildInfoRow(
        Icons.place_outlined,
        'Dónde',
        'Dentro de la zona del aula',
      ),
    ]);
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: _primaryLight, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarPlantilla() async {
    await Clipboard.setData(
      const ClipboardData(text: 'Cédula;Nombre;Correo\n'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Plantilla copiada. Pégala en Excel, llena una fila por '
          'estudiante y pega el resultado en "Importar estudiantes".',
        ),
      ),
    );
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
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 2),
        const Text(
          'Universidad de la Amazonia',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
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
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.08));
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
                        fontSize: 13,
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
