import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../attendance/attendance_radar_screen.dart';
import 'teacher_settings_screen.dart';
import 'course_detail_screen.dart';
import '../../utils/app_theme.dart';
import '../../widgets/botones_accesibles.dart';
import '../../models/curso_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/teacher_viewmodel.dart';
import '../student/student_home_screen.dart';
import 'create_course_screen.dart';

enum CourseStatus { active, today, archived }

class TeacherCourseModel {
  /// El curso en Firestore del que sale esta tarjeta.
  final Curso curso;

  final String code;
  final String name;
  final String group;
  final String location;
  final String schedule;

  /// Null mientras no haya sesiones con asistencia registrada.
  final int? attendancePercent;
  final int enrolledCount;
  final CourseStatus status;
  final String statusLabel;
  final bool isSpecialToday;

  /// Texto del pie de la tarjeta (próxima clase, clase en curso...).
  final String footer;

  const TeacherCourseModel({
    required this.curso,
    required this.code,
    required this.name,
    required this.group,
    required this.location,
    required this.schedule,
    this.attendancePercent,
    required this.enrolledCount,
    required this.status,
    required this.statusLabel,
    this.isSpecialToday = false,
    this.footer = '',
  });
}

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  // Colores extraídos del HTML de Stitch
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceBright = Color(0xFF39393B);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _systemAmber = Color(0xFFFF9F0A);

  int _selectedFilter = 0; // 0: Todos, 1: Activos, 2: Hoy, 3: Archivados

  /// Lo que se escribe en el buscador: filtra por nombre, código o grupo.
  final _buscador = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  bool _coincide(TeacherCourseModel c) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [c.name, c.code, c.group, c.location]
        .any((campo) => campo.toLowerCase().contains(q));
  }

  Future<void> _archivar(TeacherCourseModel course, bool archivar) async {
    final vm = context.read<TeacherViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final listo = await vm.archivarCurso(course.curso.id, archivado: archivar);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          !listo
              ? vm.error ?? 'No se pudo cambiar el curso.'
              : archivar
                  ? '"${course.name}" archivado. Está en el filtro Archivados.'
                  : '"${course.name}" está activo otra vez.',
        ),
        backgroundColor: listo ? null : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final chairaData = authVM.usuarioActual;
    final nombre = chairaData?.nombre ?? 'Usuario';
    final fotoBytes = chairaData?.imagenBytes;

    final teacherVM = context.watch<TeacherViewModel>();
    final uid = authVM.perfil?.uid;
    if (uid != null) teacherVM.vigilarCursos(uid);
    final ahora = DateTime.now();
    final courses = teacherVM.cursos
        .map((c) => _aModelo(c, ahora, teacherVM.promedioDe(c.id)?.porcentaje))
        .toList();

    List<TeacherCourseModel> filteredCourses = courses.where(_coincide).toList();
    if (_selectedFilter == 1) {
      filteredCourses = filteredCourses
          .where((c) => c.status != CourseStatus.archived)
          .toList();
    } else if (_selectedFilter == 2) {
      filteredCourses = filteredCourses
          .where((c) => c.isSpecialToday || c.status == CourseStatus.today)
          .toList();
    } else if (_selectedFilter == 3) {
      filteredCourses = filteredCourses
          .where((c) => c.status == CourseStatus.archived)
          .toList();
    }

    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. TOP APP BAR Y STATUS BAR SIMULADA
                _buildTopAppBar(),

                // 2. PRIMARY HEADER SECTION (Nombre, Avatar, Semestre)
                _buildPrimaryHeader(nombre: nombre, fotoBytes: fotoBytes),

                // 3. SEGMENTED CONTROL (Docente / Estudiante)
                _buildSegmentedControl(context),

                // 4. SEARCH & FILTER CHIPS
                _buildSearchAndFilters(
                  todos: courses.length,
                  activos: courses
                      .where((c) => c.status != CourseStatus.archived)
                      .length,
                  hoy: courses
                      .where(
                        (c) => c.isSpecialToday || c.status == CourseStatus.today,
                      )
                      .length,
                  archivados: courses
                      .where((c) => c.status == CourseStatus.archived)
                      .length,
                ),

                // 5. LISTA DE CURSOS (WALLET PASS STYLE)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      if (teacherVM.cargando)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (teacherVM.error != null)
                        _buildMensajeLista(teacherVM.error!)
                      else if (courses.isEmpty)
                        _buildMensajeLista(
                          'Aún no tienes cursos. Toca "Crear Curso" para '
                          'agregar el primero.',
                        )
                      else if (filteredCourses.isEmpty)
                        _buildMensajeLista(
                          _busqueda.trim().isNotEmpty
                              ? 'Ningún curso coincide con "${_busqueda.trim()}".'
                              : 'Ningún curso en este filtro.',
                        ),
                      ...filteredCourses.map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _TeacherCourseCard(
                            course: course,
                            onArchivar: (activo) => _archivar(course, !activo),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CourseDetailScreen(curso: course.curso),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 6. FLOATING ACTION BUTTON (+ Crear Curso / CSV -> Pantallas 10 y 13)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: _buildFloatingActionButton(context)),
            ),
          ],
        ),
      ),
    );
  }

  static const _dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  /// Convierte un curso de Firestore al modelo que pintan las tarjetas.
  TeacherCourseModel _aModelo(Curso curso, DateTime ahora, int? promedio) {
    // Un curso archivado no ofrece el radar aunque sea su hora. Las clases
    // extra cuentan igual que las del horario.
    final enCurso = curso.archivado ? null : curso.franjaEn(ahora);
    final pendienteHoy = curso.archivado
        ? const <Franja>[]
        : curso.franjasDe(ahora).where((f) => f.inicio.isAfter(ahora)).toList();
    // Hay clase hoy que todavía no termina: se ofrece iniciar el radar.
    final hoy = enCurso != null || pendienteHoy.isNotEmpty;
    final dias = curso.horarios.map((h) => _dias[h.dia]).toSet().join(' / ');
    final primera = curso.horarios.isEmpty ? null : curso.horarios.first;
    return TeacherCourseModel(
      curso: curso,
      code: curso.codigo,
      name: curso.nombre,
      group: [
        if (curso.grupo.isNotEmpty) 'Grupo ${curso.grupo}',
        if (curso.aula.isNotEmpty) curso.aula,
      ].join(' • '),
      location: curso.periodo,
      schedule: primera == null
          ? 'Sin horario'
          : '$dias • ${primera.inicio} - ${primera.fin}',
      attendancePercent: promedio,
      enrolledCount: curso.totalInscritos,
      status: curso.archivado
          ? CourseStatus.archived
          : enCurso != null
              ? CourseStatus.today
              : CourseStatus.active,
      statusLabel: curso.archivado
          ? 'Archivado'
          : enCurso != null
              ? 'En clase'
              : 'Activo',
      isSpecialToday: hoy,
      footer: curso.archivado
          ? 'Archivado: sin radar. Actívalo con el interruptor.'
          : enCurso != null
          ? '${enCurso.esExtra ? 'Clase extra' : 'Clase'} en curso hasta '
              '${_hhmm(enCurso.fin)}'
          : pendienteHoy.isNotEmpty
              ? '${pendienteHoy.first.esExtra ? 'Clase extra' : 'Próxima clase'}'
                  ' hoy ${_hhmm(pendienteHoy.first.inicio)}'
              : _proximaClase(curso, ahora),
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// "Próxima clase: Mié 08:00" (o "Clase extra: ...") a partir de mañana,
  /// o "Sin horario".
  String _proximaClase(Curso curso, DateTime ahora) {
    for (var dias = 1; dias <= 7; dias++) {
      final fecha = DateTime(ahora.year, ahora.month, ahora.day + dias);
      final franjas = curso.franjasDe(fecha);
      if (franjas.isEmpty) continue;
      final cuando = dias == 1 ? 'mañana' : _dias[fecha.weekday];
      final que = franjas.first.esExtra ? 'Clase extra' : 'Próxima clase';
      return '$que: $cuando ${_hhmm(franjas.first.inicio)}';
    }
    return curso.horarios.isEmpty ? 'Sin horario' : 'Sin clases esta semana';
  }

  Widget _buildMensajeLista(String mensaje) {
    return Padding(
      padding: const EdgeInsets.only(top: 48, left: 24, right: 24),
      child: Text(
        mensaje,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.shield, color: _primaryLight, size: 20),
              SizedBox(width: 8),
              Text(
                'SmartCheck',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherSettingsScreen(),
                ),
              );
            },
            tooltip: 'Ajustes',
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryHeader({
    required String nombre,
    required dynamic fotoBytes,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'UNIVERSIDAD DE LA AMAZONIA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryIndigo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryIndigo.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        Curso.periodoActual(),
                        style: const TextStyle(
                          color: _primaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Con la letra o la pantalla en grande se encoge en vez de
                // salirse.
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Panel Docente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Avatar con anillo verde
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _tertiaryGreen, width: 2),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    // Solo para el docente que también cursa materias.
    if (!(context.watch<AuthViewModel>().perfil?.esDual ?? false)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _surfaceControl,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, color: _primaryLight, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Docente',
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
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Solo los docentes que también cursan materias.
                  final perfil = context.read<AuthViewModel>().perfil;
                  if (perfil == null || !perfil.esEstudiante) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tu cuenta no tiene perfil de estudiante.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentHomeScreen(),
                    ),
                  );
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: AppTheme.textSecondary,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Estudiante',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters({
    required int todos,
    required int activos,
    required int hoy,
    required int archivados,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Input de búsqueda
          Container(
            height: 50,
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _buscador,
                    onChanged: (texto) => setState(() => _busqueda = texto),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Buscar asignatura, grupo o código...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_busqueda.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() {
                      _buscador.clear();
                      _busqueda = '';
                    }),
                    tooltip: 'Borrar la búsqueda',
                    icon: const Icon(
                      Icons.cancel,
                      color: AppTheme.textTertiary,
                      size: 18,
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Chips de filtro horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'Todos', '$todos'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  1,
                  'Activos',
                  '$activos',
                  dotColor: _tertiaryGreen,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  2,
                  'Hoy',
                  '$hoy',
                  icon: Icons.schedule,
                  iconColor: _systemAmber,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  3,
                  'Archivados',
                  '$archivados',
                  icon: Icons.archive_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    int index,
    String label,
    String? count, {
    Color? dotColor,
    IconData? icon,
    Color? iconColor,
  }) {
    final isSelected = _selectedFilter == index;
    return Tocable(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _primaryIndigo : _surfaceControl,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              CircleAvatar(radius: 3.5, backgroundColor: dotColor),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? AppTheme.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : _surfaceBright,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return Tocable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateCourseScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _primaryIndigo,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: _primaryIndigo.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Icon(Icons.upload_file, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Crear Curso / CSV',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherCourseCard extends StatelessWidget {
  final TeacherCourseModel course;
  final VoidCallback onTap;

  /// Activo (true) o archivado (false), según el interruptor.
  final ValueChanged<bool> onArchivar;

  const _TeacherCourseCard({
    required this.course,
    required this.onTap,
    required this.onArchivar,
  });

  @override
  Widget build(BuildContext context) {
    final isArchived = course.status == CourseStatus.archived;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isArchived
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.6)
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                              color: isArchived
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFF5E5CE6)
                                        .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course.code,
                              style: TextStyle(
                                color: isArchived
                                    ? AppTheme.textSecondary
                                    : const Color(0xFFC2C1FF),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            course.location,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.name,
                        style: TextStyle(
                          color: isArchived
                              ? AppTheme.textSecondary
                              : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        course.group,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Junto con "Activo" debajo, para que TalkBack lo lea como
                // un interruptor con nombre y el dedo tenga dónde caer.
                MergeSemantics(
                  child: Column(
                    children: [
                      CupertinoSwitch(
                        value: !isArchived,
                        activeTrackColor: const Color(0xFF30D158),
                        onChanged: onArchivar,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArchived ? 'Archivado' : 'Activo',
                        style: TextStyle(
                          color: isArchived
                              ? AppTheme.textSecondary
                              : const Color(0xFF47E266),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Caja de métricas intermedias (Gráfico circular + Asistencia)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: (course.attendancePercent ?? 0) / 100,
                              backgroundColor: const Color(0xFF39393B),
                              color: (course.attendancePercent ?? 100) < 80
                                  ? const Color(0xFFFF9F0A)
                                  : const Color(0xFF47E266),
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            course.attendancePercent == null
                                ? '—'
                                : '${course.attendancePercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asistencia Global',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            course.enrolledCount == 1
                                ? '1 Alumno inscrito'
                                : '${course.enrolledCount} Alumnos inscritos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF39393B).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.schedule.split('•').first.trim(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.schedule.contains('•')
                            ? course.schedule.split('•').last.trim()
                            : course.schedule,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Footer de la tarjeta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Icon(
                        course.isSpecialToday ? Icons.timer : Icons.event,
                        color: course.isSpecialToday
                            ? const Color(0xFFFF9F0A)
                            : AppTheme.textSecondary,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          course.footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: course.isSpecialToday
                                ? const Color(0xFFFF9F0A)
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: course.isSpecialToday
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (course.isSpecialToday)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AttendanceRadarScreen(curso: course.curso),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E5CE6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Tomar asistencia',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
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
