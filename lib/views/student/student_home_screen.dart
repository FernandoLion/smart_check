import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/asistencia_resumen.dart';
import '../../models/student_subject_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/student_viewmodel.dart';
import '../teacher/teacher_home_screen.dart';
import '../attendance/ble_beacon_screen.dart';
import 'attendance_detail_screen.dart';
import 'student_settings_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  // Colores exactos del HTML de Stitch
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final studentVM = context.watch<StudentViewModel>();

    final chairaData = authVM.usuarioActual;
    final nombre = chairaData?.nombre ?? 'Usuario';
    final programa = chairaData?.programa ?? 'Ingeniería de Sistemas';
    final fotoBytes = chairaData?.imagenBytes;

    final perfil = authVM.perfil;
    if (perfil != null) {
      context
          .read<StudentViewModel>()
          .vigilarCursos(cedula: perfil.cedula, email: perfil.email);
    }

    return Scaffold(
      backgroundColor: Colors.black, // bg-surface-oled
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. STICKY HEADER CON IDENTIDAD Y ACCIONES
                _buildStickyHeader(
                  context,
                  nombre: nombre,
                  programa: programa,
                  periodo: studentVM.currentPeriod,
                  fotoBytes: fotoBytes,
                ),

                // 2. MAIN SCROLLABLE CANVAS
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      // Título "Portal Estudiante" + Segmented Control (Docente / Estudiante)
                      _buildTitleAndSwitcher(
                        context,
                        totalSubjects: studentVM.subjects.length,
                      ),
                      const SizedBox(height: 20),

                      // Quick Stats Bento Banner (asistencia global y materias)
                      _buildQuickStatsBanner(studentVM),
                      const SizedBox(height: 24),

                      // Encabezado "Semáforo de Asistencia"
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Semáforo de Asistencia',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Mínimo ${AsistenciaResumen.minimo}%',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tarjetas de Asignaturas (Apple Wallet Pass Cards)
                      ..._buildSubjects(context, studentVM),
                    ],
                  ),
                ),
              ],
            ),

            // 3. FLOATING ACTION BUTTON (Registrar Asistencia -> Pantalla 6)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildFloatingAttendanceButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(
    BuildContext context, {
    required String nombre,
    required String programa,
    required String periodo,
    required dynamic fotoBytes,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Avatar + Nombre + Carrera + Periodo
          Expanded(
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceControl,
                        border: Border.all(color: _tertiaryGreen, width: 1.5),
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
                              size: 22,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _tertiaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
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
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            programa,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceControl,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              periodo,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botones de Notificaciones y Configuración (Pantalla 8)
          Row(
            children: [
              // Notificaciones con punto rojo
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 20,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _systemRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón Ajustes -> Navega a Pantalla 8 (Configuración Estudiante)
              GestureDetector(
                onTap: () => _onSettingsTap(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleAndSwitcher(
    BuildContext context, {
    required int totalSubjects,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEMESTRE ACADÉMICO',
                  style: TextStyle(
                    color: _primaryIndigo,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Portal Estudiante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Text(
              '$totalSubjects Asignaturas',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        // CupertinoSlidingSegmentedControl (Docente / • Estudiante)
        // Solo para quien es docente y también cursa materias.
        if (context.watch<AuthViewModel>().perfil?.esDual ?? false) ...[
          const SizedBox(height: 12),
          Container(
            height: 38,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceControl,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Solo los docentes que también cursan materias.
                      final perfil = context.read<AuthViewModel>().perfil;
                      if (perfil == null || !perfil.esDocente) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tu cuenta no tiene perfil docente.'),
                          ),
                        );
                        return;
                      }
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherHomeScreen(),
                        ),
                      );
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Docente',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: _tertiaryGreen),
                        SizedBox(width: 6),
                        Text(
                          'Estudiante',
                          style: TextStyle(
                            color: Colors.white,
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
      ],
    );
  }

  Widget _buildQuickStatsBanner(StudentViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Card 1: Asistencia 91%
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceControl.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.how_to_reg,
                        color: _tertiaryGreen,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Asistencia',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vm.globalAttendance == null
                        ? '—'
                        : '${vm.globalAttendance}%',
                    style: const TextStyle(
                      color: _tertiaryGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vm.globalAttendanceStatus,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Card 2: Créditos 18 / 18
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceControl.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        color: _systemAmber,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Materias',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vm.subjects.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Inscritas',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Card 3: materias por debajo del mínimo de asistencia
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceControl.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _systemRed,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'En riesgo',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vm.materiasEnRiesgo}',
                    style: TextStyle(
                      color: vm.materiasEnRiesgo == 0
                          ? Colors.white
                          : _systemRed,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Materias',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSubjects(BuildContext context, StudentViewModel vm) {
    if (vm.cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: _primaryIndigo),
          ),
        ),
      ];
    }
    if (vm.error != null) {
      return [_buildAviso(Icons.error_outline, vm.error!, _systemRed)];
    }
    if (vm.subjects.isEmpty) {
      return [
        _buildAviso(
          Icons.school_outlined,
          'Todavía no estás inscrito en ninguna materia. El docente te '
          'inscribe con tu cédula o tu correo al crear el curso.',
          AppTheme.textSecondary,
        ),
      ];
    }
    return vm.subjects
        .map(
          (subject) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _SubjectPassCard(
              subject: subject,
              onTap: () => _onSubjectTap(context, subject),
            ),
          ),
        )
        .toList();
  }

  Widget _buildAviso(IconData icono, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAttendanceButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _onRegisterAttendanceTap(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryIndigo,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        elevation: 10,
        shadowColor: _primaryIndigo.withValues(alpha: 0.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contactless, size: 22),
          SizedBox(width: 8),
          Text(
            'Registrar Asistencia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

void _onRegisterAttendanceTap(BuildContext context) {
  final perfil = context.read<AuthViewModel>().perfil;
  final clave = perfil?.cedula ?? perfil?.email;
  if (clave == null || clave.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tu sesión expiró. Vuelve a entrar.')),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BleBeaconScreen(
        cursos: context.read<StudentViewModel>().cursos,
        clave: clave,
      ),
    ),
  );
}

  void _onSubjectTap(BuildContext context, StudentSubjectModel subject) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceDetailScreen(subject: subject),
    ),
  );
}

void _onSettingsTap(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const StudentSettingsScreen(),
    ),
  );
}
}

/// Widget de Tarjeta de Asignatura (Semáforo Ámbar / Verde / Rojo)
class _SubjectPassCard extends StatelessWidget {
  final StudentSubjectModel subject;
  final VoidCallback onTap;

  const _SubjectPassCard({
    required this.subject,
    required this.onTap,
  });

  Color get _accentColor {
    switch (subject.status) {
      case NivelAsistencia.atencion:
        return const Color(0xFFFF9F0A); // system-amber
      case NivelAsistencia.alDia:
        return const Color(0xFF47E266); // tertiary
      case NivelAsistencia.riesgo:
        return const Color(0xFFFF453A); // system-red
    }
  }

  IconData get _bottomNoteIcon {
    switch (subject.status) {
      case NivelAsistencia.atencion:
        return Icons.flag;
      case NivelAsistencia.alDia:
        return Icons.verified;
      case NivelAsistencia.riesgo:
        return Icons.warning_amber_rounded;
    }
  }

  IconData get _attendanceIcon {
    switch (subject.status) {
      case NivelAsistencia.atencion:
        return Icons.fact_check_outlined;
      case NivelAsistencia.alDia:
        return Icons.check_circle_outline;
      case NivelAsistencia.riesgo:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final porcentaje = subject.attendancePercent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Barra superior de brillo (Gradient Ambient Sheen Top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER DE LA MATERIA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    color: AppTheme.surfaceControl,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    subject.code,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Grupo ${subject.group}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const Text(
                                  '•',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  subject.room,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subject.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: AppTheme.textTertiary,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${subject.schedule} • ${subject.professor}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceControl.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. CAJA CENTRAL: asistencia del estudiante en la materia
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceControl.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              porcentaje == null ? '—' : '$porcentaje%',
                              style: TextStyle(
                                color: accent,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    subject.statusLabel,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subject.sessionsLabel,
                                  style: const TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Icon(_bottomNoteIcon, color: accent, size: 26),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. BARRA DE PROGRESO DE ASISTENCIA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_attendanceIcon, color: accent, size: 14),
                            const SizedBox(width: 4),
                            const Text(
                              'Asistencia: ',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              porcentaje == null ? '— ' : '$porcentaje% ',
                              style: TextStyle(
                                color: subject.status == NivelAsistencia.atencion
                                    ? Colors.white
                                    : accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '(mínimo ${AsistenciaResumen.minimo}%)',
                                style: TextStyle(
                                  color:
                                      subject.status == NivelAsistencia.riesgo
                                          ? accent
                                          : AppTheme.textTertiary,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceControl,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          subject.absencesBadge,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    width: double.infinity,
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceControl,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (porcentaje ?? 0) / 100.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}