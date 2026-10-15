import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseName;
  final String courseCode;
  final String groupName;

  const CourseDetailScreen({
    super.key,
    this.courseName = 'Ingeniería de Software II',
    this.courseCode = 'SIS-402',
    this.groupName = 'Grupo 302-B',
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Colores exactos del HTML de Stitch
  static const Color _surfaceOled = Color(0xFF0E0E10);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _secondaryBlue = Color(0xFF3E90FF); // secondary-container

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER UNIFICADO (Dynamic Island + Navigation + TabBar)
            _buildHeader(context),

            // 2. CONTENIDO DE LAS PESTAÑAS (Sesiones vs Estudiantes)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // PESTAÑA 1: SESIONES (Pantalla 14)
                  _buildSessionsTab(),

                  // PESTAÑA 2: ESTUDIANTES (Pantalla 15)
                  _buildStudentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: _surfaceOled.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          // Dynamic Island Capsule
          Container(
            height: 28,
            width: 176,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Navigation Bar (Back, Title & Actions)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios, color: _primaryLight, size: 18),
                    Text(
                      'Mis Clases',
                      style: TextStyle(
                        color: _primaryLight,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
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
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${widget.courseCode} • ${widget.groupName}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildActionCircle(Icons.person_add_outlined),
                  const SizedBox(width: 6),
                  _buildActionCircle(Icons.more_horiz),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cupertino Segmented Control (Sesiones / Estudiantes)
          Container(
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.event_note, size: 16),
                      SizedBox(width: 6),
                      Text('Sesiones'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 6),
                      const Text('Estudiantes'),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryIndigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '24',
                          style: TextStyle(
                            color: _primaryLight,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _surfaceControl.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: _primaryLight, size: 17),
    );
  }

  // ==========================================
  // PESTAÑA 1: SESIONES (Pantalla 14)
  // ==========================================
  Widget _buildSessionsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Card: Sesión de Hoy Destacada
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: _tertiaryGreen),
                      SizedBox(width: 8),
                      Text(
                        'CLASE DE HOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _tertiaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _tertiaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: _tertiaryGreen,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Inicia en 15 min',
                          style: TextStyle(
                            color: _tertiaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.schedule, color: _primaryLight, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '08:00 - 10:00 AM • Hoy Jueves',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.place_outlined, color: _secondaryBlue, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Bloque B2 • Pabellón Central (Geocerca ±25m)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live Mini Metrics
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surfaceControl.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alumnos Registrados',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '24 inscritos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.person_outline,
                            color: AppTheme.textTertiary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surfaceControl.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Esperada Promedio',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '88% asistencia',
                                style: TextStyle(
                                  color: _tertiaryGreen,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.trending_up,
                            color: _tertiaryGreen,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensors, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Iniciar Radar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _surfaceControl,
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pin_drop_outlined,
                            color: _secondaryBlue,
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Editar Geocerca',
                            style: TextStyle(
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
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section: Historial de Clases Pasadas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Text(
                  'SESIONES ANTERIORES',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '(14 registradas)',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {},
              child: const Row(
                children: [
                  Icon(Icons.tune, color: _primaryLight, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'Filtrar',
                    style: TextStyle(
                      color: _primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: _surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildSessionTile('Mar', '18', 'Martes 18 de Marzo', 'Cerrada', '92% (22/24)', '08:05 - 09:55 AM', isFirst: true),
              _buildDivider(),
              _buildSessionTile('Jue', '13', 'Jueves 13 de Marzo', 'Reporte generado', '88% (21/24)', '08:00 - 10:00 AM'),
              _buildDivider(),
              _buildSessionTile('Mar', '11', 'Martes 11 de Marzo', 'Cerrada', '96% (23/24)', '08:02 - 10:01 AM'),
              _buildDivider(),
              _buildSessionTile('Jue', '06', 'Jueves 6 de Marzo', 'Baja asistencia', '75% (18/24)', '08:00 - 10:00 AM', isWarning: true, isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTile(
    String dayShort,
    String dayNum,
    String title,
    String badgeText,
    String stats,
    String time, {
    bool isFirst = false,
    bool isLast = false,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Calendario miniatura
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _surfaceControl,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayShort,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dayNum,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isWarning ? _systemAmber.withValues(alpha: 0.2) : _surfaceControl,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isWarning ? _systemAmber.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: isWarning ? _systemAmber : AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            stats,
                            style: TextStyle(
                              color: isWarning ? _systemAmber : _tertiaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(color: AppTheme.textTertiary),
                          ),
                          Flexible(
                            child: Text(
                              time,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: ESTUDIANTES (Pantalla 15)
  // ==========================================
  Widget _buildStudentsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Search Field
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surfaceControl,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  style: TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o ID de estudiante...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Icon(Icons.cancel, color: AppTheme.textTertiary, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Institutional Metric Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school, color: _primaryLight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '24 Inscritos',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 6),
                          CircleAvatar(radius: 2.5, backgroundColor: AppTheme.textTertiary),
                          SizedBox(width: 6),
                          Text(
                            '3 en Riesgo',
                            style: TextStyle(color: _systemRed, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Regla Institucional: Máx. 6 faltas (20%)',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '91.4%',
                    style: TextStyle(color: _tertiaryGreen, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Promedio',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Header: Lista de Inscritos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LISTA DE INSCRITOS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      'Ordenar por riesgo',
                      style: TextStyle(color: _primaryLight, fontSize: 12),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.swap_vert, color: _primaryLight, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Tarjetas de Estudiantes con Termómetro Individual
        _buildStudentRiskCard(
          name: 'Mateo Gómez Silva',
          id: 'ID: 2022-1049 • Ing. Sistemas',
          faultsText: 'Faltas: 1/6 (3%)',
          attendanceText: '97% Asist.',
          badgeLabel: 'Normal',
          badgeColor: _tertiaryGreen,
          progressFraction: 0.16,
          riskTitle: 'Límite de Faltas (1 de 6)',
          riskSubtitle: 'Margen Seguro',
          isRiskCritical: false,
        ),
        const SizedBox(height: 12),

        _buildStudentRiskCard(
          name: 'Diego Fernando Parra',
          id: 'ID: 2021-9923 • Ing. Sistemas',
          faultsText: 'Faltas: 5/6 (18%)',
          attendanceText: '82% Asist.',
          badgeLabel: 'Riesgo Crítico',
          badgeColor: _systemRed,
          progressFraction: 0.83,
          riskTitle: '5 de 6 faltas acumuladas',
          riskSubtitle: '1 falta para reprobación',
          isRiskCritical: true,
        ),
        const SizedBox(height: 12),

        _buildStudentRiskCard(
          name: 'Valentina Rios Morales',
          id: 'ID: 2021-8842 • Ing. Sistemas',
          faultsText: 'Faltas: 4/6 (13%)',
          attendanceText: '87% Asist.',
          badgeLabel: 'Alerta',
          badgeColor: _systemAmber,
          progressFraction: 0.66,
          riskTitle: '4 de 6 faltas (Zona de Alerta)',
          riskSubtitle: '2 faltas restantes',
          isWarning: true,
        ),
        const SizedBox(height: 12),

        _buildStudentRiskCard(
          name: 'Sofía Mendoza Cruz',
          id: 'ID: 2022-3419 • Ing. Software',
          faultsText: 'Faltas: 0/6 (0%)',
          attendanceText: '100% Asist.',
          badgeLabel: 'Normal',
          badgeColor: _tertiaryGreen,
          progressFraction: 0.04,
          riskTitle: 'Sin inasistencias registradas',
          riskSubtitle: 'Asistencia Perfecta',
        ),
        const SizedBox(height: 16),

        // Quick Action Footer Note (Acuerdo 014)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceControl.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acuerdo Académico 014: El estudiante que supere el 20% de inasistencias no justificadas (6 sesiones) reprueba automáticamente la asignatura.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRiskCard({
    required String name,
    required String id,
    required String faultsText,
    required String attendanceText,
    required String badgeLabel,
    required Color badgeColor,
    required double progressFraction,
    required String riskTitle,
    required String riskSubtitle,
    bool isRiskCritical = false,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRiskCritical
              ? _systemRed.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(Icons.person, color: AppTheme.textSecondary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            id,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                faultsText,
                                style: TextStyle(
                                  color: isRiskCritical
                                      ? _systemRed
                                      : isWarning
                                          ? _systemAmber
                                          : _tertiaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(' • ', style: TextStyle(color: AppTheme.textTertiary)),
                              Text(
                                attendanceText,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
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
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Termómetro de Riesgo individual
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    riskTitle,
                    style: TextStyle(
                      color: isRiskCritical ? _systemRed : isWarning ? _systemAmber : AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: isRiskCritical ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    riskSubtitle,
                    style: TextStyle(
                      color: isRiskCritical ? _systemRed : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isRiskCritical ? FontWeight.bold : FontWeight.normal,
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
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressFraction.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRiskCritical
                          ? _systemRed
                          : isWarning
                              ? _systemAmber
                              : _tertiaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}