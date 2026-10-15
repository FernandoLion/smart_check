import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'add_student_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final String courseName;
  final String courseCodeAndGroup;
  final String sessionDateTitle;
  final String sessionTimeRange;
  final String sessionId;
  final int presentCount;
  final int totalCount;

  const SessionDetailScreen({
    super.key,
    this.courseName = 'Ingeniería de Software II',
    this.courseCodeAndGroup = 'SIS-402 • Grupo 302-B',
    this.sessionDateTitle = 'Martes 18 de Marzo, 2025',
    this.sessionTimeRange = '08:05 AM – 09:55 AM',
    this.sessionId = 'ID #SES-402-99',
    this.presentCount = 22,
    this.totalCount = 24,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceContainer = Color(0xFF1F1F21);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _surfaceVariant = Color(0xFF353437);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _secondaryLight = Color(0xFFAAC7FF); // secondary
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _errorContainer = Color(0xFF93000A);

  int _selectedFilter = 0; // 0: Todos, 1: Presentes, 2: Ausentes

  late List<_SessionStudentRecord> _students;

  @override
  void initState() {
    super.initState();
    _students = [
      const _SessionStudentRecord(
        name: 'Mateo Gómez Silva',
        subtitle: 'ID: 2020-8812 • Asistencia 100%',
        initials: 'MG',
        isPresent: true,
        methodBadge: 'BLE -54 dBm',
        methodType: _ValidationMethod.ble,
        timeText: '08:06 AM',
      ),
      const _SessionStudentRecord(
        name: 'Lucía Beltrán Restrepo',
        subtitle: 'ID: 2021-3920 • Asistencia 92%',
        initials: 'LB',
        isPresent: false,
        methodBadge: 'Ausente',
        methodType: _ValidationMethod.absent,
        timeText: 'Cambiar estado',
      ),
      const _SessionStudentRecord(
        name: 'Camila Morales Rivas',
        subtitle: 'ID: 2021-1149 • Asistencia 96%',
        initials: 'CM',
        isPresent: true,
        methodBadge: 'Face ID',
        methodType: _ValidationMethod.faceId,
        timeText: '08:08 AM',
      ),
      const _SessionStudentRecord(
        name: 'Santiago Torres Vaca',
        subtitle: 'ID: 2020-5621 • Asistencia 88%',
        initials: 'ST',
        isPresent: true,
        methodBadge: 'Llamado Docente',
        methodType: _ValidationMethod.manual,
        timeText: '08:14 AM',
      ),
    ];
  }

  void _toggleStudentAttendance(int indexInFullList) {
    setState(() {
      final current = _students[indexInFullList];
      if (current.isPresent) {
        _students[indexInFullList] = current.copyWith(
          isPresent: false,
          methodBadge: 'Ausente',
          methodType: _ValidationMethod.absent,
          timeText: 'Cambiar estado',
        );
      } else {
        _students[indexInFullList] = current.copyWith(
          isPresent: true,
          methodBadge: 'Llamado Docente',
          methodType: _ValidationMethod.manual,
          timeText: 'Manual',
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Estado de asistencia actualizado en la sesión'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int absentCount = widget.totalCount - widget.presentCount;
    final double presentPercent =
        (widget.presentCount / widget.totalCount) * 100.0;
    final double absentPercent = 100.0 - presentPercent;

    final filteredStudents = _students.where((s) {
      if (_selectedFilter == 1) return s.isPresent;
      if (_selectedFilter == 2) return !s.isPresent;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER STICKY (Dynamic Island + Barra de Navegación)
            _buildTopHeader(context),

            // 2. MAIN SCROLLABLE CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  // Tarjeta 1: Hero Resumen de la Sesión
                  _buildHeroSummaryCard(
                    absentCount: absentCount,
                    presentPercent: presentPercent,
                    absentPercent: absentPercent,
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta 2: Desglose Tecnológico de Marcación (SmartCheck Core)
                  _buildTechBreakdownCard(),
                  const SizedBox(height: 16),

                  // Filtro por Estado (Cupertino Sliding Segmented Control)
                  _buildFilterSegmentedControl(absentCount),
                  const SizedBox(height: 16),

                  // Lista Detallada de Estudiantes Registrados
                  _buildStudentsListSection(filteredStudents),
                  const SizedBox(height: 20),

                  // Acciones al pie de página (Exportar PDF/Excel + Reabrir Asistencia)
                  _buildFooterActions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: _surfaceOled.withValues(alpha: 0.9),
      ),
      child: Column(
        children: [
          // Dynamic Island Capsule
          Container(
            height: 32,
            width: 176,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _surfaceOled,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _primaryIndigo,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'BLE Activo',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.sensors, color: _primaryLight, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'SmartCheck',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Navigation Bar (iOS Back, Titles, Action)
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        color: _primaryIndigo,
                        size: 18,
                      ),
                      Text(
                        'Mis Clases',
                        style: TextStyle(
                          color: _primaryIndigo,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.courseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.courseCodeAndGroup,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddStudentScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _surfaceControl.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_add_outlined,
                          color: _primaryLight,
                          size: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _surfaceControl.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard({
    required int absentCount,
    required double presentPercent,
    required double absentPercent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de estado con badge verificado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _tertiaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: _tertiaryGreen, size: 15),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Sesión Finalizada & Auditada',
                          style: TextStyle(
                            color: _tertiaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.sessionId,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título y horario
          Text(
            widget.sessionDateTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.schedule,
                color: AppTheme.textTertiary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                widget.sessionTimeRange,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: _surfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '1h 50m',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ubicación y Geocerca BLE
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surfaceControl.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.meeting_room_outlined,
                          color: _primaryLight,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bloque B2 • Aula 301',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Campus Central UDLA',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: _tertiaryGreen),
                      SizedBox(width: 5),
                      Text(
                        'Geocerca + BLE OK',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Asistencia General & Barra Tricolor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${widget.presentCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ ${widget.totalCount} Alumnos',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                '${presentPercent.toStringAsFixed(1)}% Presentismo',
                style: const TextStyle(
                  color: _tertiaryGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Barra de progreso segmentada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (presentPercent * 10).round(),
                    child: Container(color: _tertiaryGreen),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (absentPercent * 10).round(),
                    child: Container(color: _systemRed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Mini Cards de Estadísticas (3 columnas)
          Row(
            children: [
              Expanded(
                child: _buildStatMiniCard(
                  label: 'Presentes',
                  value: '${widget.presentCount}',
                  percent: '${presentPercent.toStringAsFixed(1)}%',
                  valueColor: _tertiaryGreen,
                  percentColor: _tertiaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatMiniCard(
                  label: 'Ausentes',
                  value: '$absentCount',
                  percent: '${absentPercent.toStringAsFixed(1)}%',
                  valueColor: _systemRed,
                  percentColor: _systemRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatMiniCard(
                  label: 'Justificados',
                  value: '0',
                  percent: '0.0%',
                  valueColor: _secondaryLight,
                  percentColor: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniCard({
    required String label,
    required String value,
    required String percent,
    required Color valueColor,
    required Color percentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: _surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            percent,
            style: TextStyle(
              color: percentColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined, color: _primaryLight, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'VALIDACIÓN TECNOLÓGICA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                'Motor SmartCheck v4.2',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila 1: Radar BLE Autónomo
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sensors,
                        color: _primaryLight,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radar BLE Autónomo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Cero fricción • Proximidad RSSI',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '18',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '81.8%',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Fila 2: Llamado Docente
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.how_to_reg_outlined,
                        color: _systemAmber,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Llamado Docente',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Validado por Prof. Jhojan F.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '4.6%',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSegmentedControl(int absentCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentTab(0, 'Todos (${widget.totalCount})'),
          _buildSegmentTab(1, 'Presentes (${widget.presentCount})'),
          _buildSegmentTab(2, 'Ausentes ($absentCount)'),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, String label) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsListSection(List<_SessionStudentRecord> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESTUDIANTES REGISTRADOS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.tune, color: _primaryLight, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Ordenar por hora',
                    style: TextStyle(
                      color: _primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...students.map((student) {
          final originalIndex = _students.indexOf(student);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildStudentRecordCard(student, originalIndex),
          );
        }),
      ],
    );
  }

  Widget _buildStudentRecordCard(
    _SessionStudentRecord student,
    int originalIndex,
  ) {
    Color statusDotColor;
    IconData statusDotIcon = Icons.check;
    Color badgeBgColor;
    Color badgeTextColor;
    IconData? badgeIcon;

    switch (student.methodType) {
      case _ValidationMethod.ble:
        statusDotColor = _tertiaryGreen;
        badgeBgColor = _tertiaryContainer.withValues(alpha: 0.25);
        badgeTextColor = _tertiaryGreen;
        badgeIcon = Icons.sensors;
        break;
      case _ValidationMethod.faceId:
        statusDotColor = _tertiaryGreen;
        badgeBgColor = _surfaceContainer;
        badgeTextColor = _secondaryLight;
        badgeIcon = Icons.face;
        break;
      case _ValidationMethod.manual:
        statusDotColor = _systemAmber;
        badgeBgColor = _systemAmber.withValues(alpha: 0.2);
        badgeTextColor = _systemAmber;
        badgeIcon = Icons.edit_note;
        break;
      case _ValidationMethod.absent:
        statusDotColor = _systemRed;
        statusDotIcon = Icons.close;
        badgeBgColor = _errorContainer.withValues(alpha: 0.35);
        badgeTextColor = _systemRed;
        badgeIcon = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        student.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -3,
                      right: -3,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: statusDotColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusDotIcon,
                          size: 10,
                          color: student.isPresent
                              ? Colors.black
                              : Colors.white,
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
                        student.name,
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
                        student.subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null) ...[
                      Icon(badgeIcon, color: badgeTextColor, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      student.methodBadge,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _toggleStudentAttendance(originalIndex),
                child: Text(
                  student.timeText,
                  style: TextStyle(
                    color: student.isPresent
                        ? AppTheme.textTertiary
                        : _primaryLight,
                    fontSize: 12,
                    fontWeight: student.isPresent
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exportando reporte oficial de la sesión...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryIndigo,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ios_share, size: 20),
              SizedBox(width: 8),
              Text(
                'Exportar Reporte Oficial (PDF / Excel)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Asistencia reabierta para edición manual'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          style: TextButton.styleFrom(
            backgroundColor: _surfaceControl,
            foregroundColor: AppTheme.textSecondary,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_reset, size: 18),
              SizedBox(width: 6),
              Text(
                'Reabrir Asistencia para Corrección',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              color: AppTheme.textTertiary,
              size: 14,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Registro sincronizado con la plataforma académica Chairá UDLA.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ValidationMethod { ble, faceId, manual, absent }

class _SessionStudentRecord {
  final String name;
  final String subtitle;
  final String initials;
  final bool isPresent;
  final String methodBadge;
  final _ValidationMethod methodType;
  final String timeText;

  const _SessionStudentRecord({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.isPresent,
    required this.methodBadge,
    required this.methodType,
    required this.timeText,
  });

  _SessionStudentRecord copyWith({
    bool? isPresent,
    String? methodBadge,
    _ValidationMethod? methodType,
    String? timeText,
  }) {
    return _SessionStudentRecord(
      name: name,
      subtitle: subtitle,
      initials: initials,
      isPresent: isPresent ?? this.isPresent,
      methodBadge: methodBadge ?? this.methodBadge,
      methodType: methodType ?? this.methodType,
      timeText: timeText ?? this.timeText,
    );
  }
}