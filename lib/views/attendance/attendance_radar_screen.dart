import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'face_verification_screen.dart';

class AttendanceRadarScreen extends StatefulWidget {
  final String courseTitle;

  const AttendanceRadarScreen({
    super.key,
    this.courseTitle = 'Ing. de Software • Aula 302B',
  });

  @override
  State<AttendanceRadarScreen> createState() => _AttendanceRadarScreenState();
}

class _AttendanceRadarScreenState extends State<AttendanceRadarScreen>
    with TickerProviderStateMixin {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceContainer = Color(0xFF1F1F21);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceBright = Color(0xFF39393B);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _secondaryBlue = Color(0xFF3E90FF); // secondary-container
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryFixed = Color(0xFF6CFF82); // tertiary-fixed
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _errorContainer = Color(0xFF93000A);

  late final AnimationController _sweepController;
  late final AnimationController _pulseController;

  bool _isRadarActive = true;
  int _selectedFilter = 0; // 0: Todos (24), 1: Detectados (18), 2: Ausentes (6)

  final List<_RadarStudentItem> _students = const [
    _RadarStudentItem(
      name: 'Valentina Rios Morales',
      idAndProgram: 'ID: 2021-0492 • Ing. de Sistemas',
      signalDetail: 'Detectado hace 2m • 100% señal',
      timeText: '08:14 AM',
      initials: 'VR',
      isPresent: true,
    ),
    _RadarStudentItem(
      name: 'Camilo Torres Peña',
      idAndProgram: 'ID: 2022-1180 • Ing. de Sistemas',
      signalDetail: 'Detectado hace 3m • 92% señal',
      timeText: '08:15 AM',
      initials: 'CT',
      isPresent: true,
    ),
    _RadarStudentItem(
      name: 'Sofía Mendoza Cruz',
      idAndProgram: 'ID: 2021-3042 • Ing. de Software',
      signalDetail: 'Detectado hace 5m • 88% señal',
      timeText: '08:17 AM',
      initials: 'SM',
      isPresent: true,
    ),
    _RadarStudentItem(
      name: 'Mateo Gómez Silva',
      idAndProgram: 'ID: 2020-8812 • Ing. de Software',
      signalDetail: 'Detectado hace 7m • 79% señal',
      timeText: '08:19 AM',
      initials: 'MG',
      isPresent: true,
    ),
    _RadarStudentItem(
      name: 'Diego Fernando Parra',
      idAndProgram: 'ID: 2021-9923 • Ing. de Software',
      signalDetail: 'Buscando baliza BLE...',
      timeText: 'Sin registro',
      initials: 'DP',
      isPresent: false,
      absentIcon: Icons.wifi_tethering_off,
    ),
    _RadarStudentItem(
      name: 'Lucía Beltrán Duarte',
      idAndProgram: 'ID: 2022-4410 • Ing. de Sistemas',
      signalDetail: 'Fuera del radio de aula',
      timeText: 'Sin registro',
      initials: 'LB',
      isPresent: false,
      absentIcon: Icons.close,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Animación continua de 360° para el haz del radar (4s linear infinite)
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Animación de pulso para el anillo cercano y los blips (3.2s infinite)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleRadarState() {
    setState(() {
      _isRadarActive = !_isRadarActive;
      if (_isRadarActive) {
        _sweepController.repeat();
      } else {
        _sweepController.stop();
      }
    });
  }

  void _onFaceVerificationTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
    );
  }

  void _onManualRollcallTap() {
    // Según el Roadmap: 21 (Radar) -> Botón "Llamado manual" -> 23 (Llamado Manual)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ir a Pantalla 23: Llamado Manual'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onCedulaLoginTap() {
    // Según el Roadmap: 21 (Radar) -> Botón "Ingresar por cédula" -> 24 (Ingreso por Cédula)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ir a Pantalla 24: Ingreso por Cédula'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _students.where((s) {
      if (_selectedFilter == 1) return s.isPresent;
      if (_selectedFilter == 2) return !s.isPresent;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. STICKY HEADER (< Mis Clases | Radar de Asistencia | BLE 2.4G)
                _buildTopHeader(context),

                // 2. MAIN SCROLLABLE CONTENT CANVAS
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                    children: [
                      // SECTION 1: High-Tech Radar Visualizer Viewport
                      _buildRadarVisualizerCard(),
                      const SizedBox(height: 16),

                      // Barra rápida de métodos alternativos (Pantallas 22 y 24 del Roadmap)
                      _buildAlternativeMethodsStrip(),
                      const SizedBox(height: 16),

                      // SECTION 2: Cupertino Sliding Segment Filter
                      _buildSegmentedFilterSection(),
                      const SizedBox(height: 12),

                      // SECTION 3: iOS Inset Grouped Attendance Cards List
                      ...filteredStudents.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildStudentAttendanceCard(student),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 3. FLOATING ACTION CONTROLS / BOTTOM BAR (Manual | Detener Radar | Exportar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFloatingBottomDock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceOled.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Leading: "< Mis Clases"
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: _secondaryBlue, size: 24),
                Text(
                  'Mis Clases',
                  style: TextStyle(color: _secondaryBlue, fontSize: 15),
                ),
              ],
            ),
          ),

          // Center: Title & Subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Radar de Asistencia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.courseTitle,
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

          // Trailing: Live BLE Pill Badge ("BLE 2.4G")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _surfaceElevated.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isRadarActive
                        ? _tertiaryGreen
                        : AppTheme.textTertiary,
                    shape: BoxShape.circle,
                    boxShadow: _isRadarActive
                        ? [
                            BoxShadow(
                              color: _tertiaryGreen.withValues(alpha: 0.7),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'BLE 2.4G',
                  style: TextStyle(
                    color: _isRadarActive
                        ? _tertiaryFixed
                        : AppTheme.textSecondary,
                    fontSize: 11,
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

  Widget _buildRadarVisualizerCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              children: [
                // Header of Radar Container: "SENSOR OMNIDIRECCIONAL" + "Escaneando..."
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sensors, color: _primaryIndigo, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'SENSOR OMNIDIRECCIONAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceControl.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: _isRadarActive
                                ? _systemAmber
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRadarActive ? 'Escaneando...' : 'En pausa',
                            style: const TextStyle(
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
                const SizedBox(height: 8),

                // Radar Canvas Box (260px height)
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Líneas guía en cruz (Crosshairs)
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      Container(
                        width: 1,
                        height: double.infinity,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),

                      // Anillo Concéntrico 1 (Perímetro exterior punteado 246px)
                      CustomPaint(
                        size: const Size(246, 246),
                        painter: _DashedRadarRingPainter(
                          color: _primaryIndigo.withValues(alpha: 0.25),
                        ),
                      ),

                      // Anillo Concéntrico 2 (Rango medio ~8m: 184px)
                      Container(
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),

                      // Anillo Concéntrico 3 (Rango cercano ~4m: 116px con pulso)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _tertiaryGreen.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ),

                      // Haz cónico giratorio del Radar (radar-sweep-beam)
                      RotationTransition(
                        turns: _sweepController,
                        child: Container(
                          width: 246,
                          height: 246,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                _primaryIndigo.withValues(alpha: 0.15),
                                _tertiaryGreen.withValues(alpha: 0.45),
                              ],
                              stops: const [0.0, 0.72, 0.88, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Blips de estudiantes detectados en las órbitas
                      // Blip 1: Valentina Rios (Top Right)
                      Positioned(
                        top: 28,
                        right: 64,
                        child: _buildStudentBlip(
                          initials: 'VR',
                          size: 32,
                          showCheck: true,
                        ),
                      ),
                      // Blip 2: Camilo Torres (Bottom Left)
                      Positioned(
                        bottom: 36,
                        left: 52,
                        child: _buildStudentBlip(initials: 'CT', size: 28),
                      ),
                      // Blip 3: Sofía Mendoza (Top Left)
                      Positioned(
                        top: 44,
                        left: 46,
                        child: _buildStudentBlip(initials: 'SM', size: 28),
                      ),
                      // Blip 4: Mateo Gómez (Bottom Right)
                      Positioned(
                        bottom: 30,
                        right: 46,
                        child: _buildStudentBlip(initials: 'MG', size: 28),
                      ),
                      // Blip 5: Mariana Ortiz (Right Center)
                      Positioned(
                        top: 108,
                        right: 22,
                        child: _buildStudentBlip(
                          initials: 'MO',
                          size: 24,
                          bgColor: _primaryIndigo.withValues(alpha: 0.4),
                        ),
                      ),
                      // Blip 6: Andrés Silva (Outer left, buscando señal)
                      Positioned(
                        bottom: 72,
                        left: 18,
                        child: Opacity(
                          opacity: 0.6,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _surfaceContainer,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.textSecondary),
                            ),
                            child: const Center(
                              child: CircleAvatar(
                                radius: 3,
                                backgroundColor: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Nodo Central: Docente Emisor
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _primaryIndigo.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _primaryIndigo,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryIndigo.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.podcasts,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _surfaceElevated.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Text(
                              'Docente Emisor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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

          // Live Metrics Bar under Radar ("18 / 24 Detectados (75%)" + "Alcance: ~8.2m")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _surfaceControl.withValues(alpha: 0.4),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Text(
                          '18 / 24',
                          style: TextStyle(
                            color: _tertiaryFixed,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Detectados (75%)',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: const [
                        Icon(Icons.radar, color: _primaryIndigo, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Alcance: ~8.2m',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _surfaceControl,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.75,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _tertiaryGreen,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _tertiaryGreen.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildStudentBlip({
    required String initials,
    required double size,
    Color? bgColor,
    bool showCheck = false,
  }) {
    return GestureDetector(
      onTap: _onFaceVerificationTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor ?? _surfaceControl,
              shape: BoxShape.circle,
              border: Border.all(color: _tertiaryGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: showCheck ? 13 : 9,
              height: showCheck ? 13 : 9,
              decoration: BoxDecoration(
                color: _tertiaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: _surfaceOled, width: 1.5),
              ),
              child: showCheck
                  ? const Icon(Icons.check, size: 8, color: Colors.black)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Barra rápida para conectar con las Pantallas 22 (Verificar cara) y 24 (Ingresar por cédula) del Roadmap
  Widget _buildAlternativeMethodsStrip() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _onFaceVerificationTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    color: _primaryIndigo,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Verificar Rostro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _onCedulaLoginTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dialpad, color: _secondaryBlue, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Ingresar Cédula',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedFilterSection() {
    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _surfaceControl,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              _buildFilterTab(index: 0, label: 'Todos', count: '(24)'),
              _buildFilterTab(
                index: 1,
                label: 'Detectados',
                count: '(18)',
                dotColor: _tertiaryGreen,
              ),
              _buildFilterTab(
                index: 2,
                label: 'Ausentes',
                count: '(6)',
                dotColor: _systemRed,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'ESTUDIANTES EN AULA (24 REGISTRADOS)',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.sort, color: _secondaryBlue, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Recientes',
                    style: TextStyle(
                      color: _secondaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required String count,
    Color? dotColor,
  }) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dotColor != null) ...[
                CircleAvatar(radius: 3, backgroundColor: dotColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textSecondary
                      : AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAttendanceCard(_RadarStudentItem student) {
    return GestureDetector(
      onTap: _onFaceVerificationTap,
      child: Opacity(
        opacity: student.isPresent ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceElevated.withValues(
              alpha: student.isPresent ? 0.9 : 0.5,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Avatar con badge de estado
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _surfaceControl,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: student.isPresent
                                  ? _tertiaryGreen
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            student.initials,
                            style: TextStyle(
                              color: student.isPresent
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: student.isPresent
                                  ? _tertiaryGreen
                                  : _surfaceBright,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              student.isPresent ? Icons.check : Icons.schedule,
                              size: 11,
                              color: student.isPresent
                                  ? Colors.black
                                  : AppTheme.textSecondary,
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
                            student.name,
                            style: TextStyle(
                              color: student.isPresent
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student.idAndProgram,
                            style: TextStyle(
                              color: student.isPresent
                                  ? AppTheme.textSecondary
                                  : AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                student.isPresent
                                    ? Icons.bluetooth_connected
                                    : (student.absentIcon ??
                                          Icons.wifi_tethering_off),
                                color: student.isPresent
                                    ? _tertiaryFixed
                                    : AppTheme.textTertiary,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  student.signalDetail,
                                  style: TextStyle(
                                    color: student.isPresent
                                        ? _tertiaryFixed
                                        : AppTheme.textTertiary,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: student.isPresent
                          ? _tertiaryGreen.withValues(alpha: 0.15)
                          : _surfaceControl,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: student.isPresent
                            ? _tertiaryGreen.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      student.isPresent ? 'Presente' : 'Ausente',
                      style: TextStyle(
                        color: student.isPresent
                            ? _tertiaryGreen
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: student.isPresent
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student.timeText,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _surfaceOled,
            _surfaceOled.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Botón Secundario Izquierdo: Pase Manual -> Pantalla 23
          GestureDetector(
            onTap: _onManualRollcallTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _surfaceControl.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    color: _secondaryBlue,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Manual',
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
          const SizedBox(width: 10),

          // Botón Primario Central: "Detener Radar" / "Reanudar Radar"
          Expanded(
            child: GestureDetector(
              onTap: _toggleRadarState,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: _isRadarActive
                      ? const LinearGradient(
                          colors: [_systemRed, _errorContainer],
                        )
                      : null,
                  color: _isRadarActive ? null : _surfaceControl,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isRadarActive
                        ? _systemRed.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: _isRadarActive
                      ? [
                          BoxShadow(
                            color: _systemRed.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRadarActive ? Icons.stop_circle : Icons.play_arrow,
                      color: _isRadarActive ? Colors.white : _tertiaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRadarActive ? 'Detener Radar' : 'Reanudar Radar',
                      style: TextStyle(
                        color: _isRadarActive ? Colors.white : _tertiaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Botón Secundario Derecho: Exportar Acta
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exportando acta de radar en vivo...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _surfaceControl.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.ios_share,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRadarRingPainter extends CustomPainter {
  final Color color;
  const _DashedRadarRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const int dashes = 40;
    const double step = (2 * math.pi) / dashes;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarStudentItem {
  final String name;
  final String idAndProgram;
  final String signalDetail;
  final String timeText;
  final String initials;
  final bool isPresent;
  final IconData? absentIcon;

  const _RadarStudentItem({
    required this.name,
    required this.idAndProgram,
    required this.signalDetail,
    required this.timeText,
    required this.initials,
    required this.isPresent,
    this.absentIcon,
  });
}
