import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ManualRollcallScreen extends StatefulWidget {
  final String courseName;

  const ManualRollcallScreen({
    super.key,
    this.courseName = 'Ing. de Software II',
  });

  @override
  State<ManualRollcallScreen> createState() => _ManualRollcallScreenState();
}

class _ManualRollcallScreenState extends State<ManualRollcallScreen> {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary / primary-fixed-dim
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);

  // Lista de los 5 estudiantes no detectados por BLE
  final List<_UndetectedStudent> _students = const [
    _UndetectedStudent(
      name: 'Diego Fernando Parra',
      idCode: 'ID: 2021-9923',
      program: 'Ing. de Software',
      semesterGroup: 'Semestre 7 • Grupo 201 • Turno Matutino',
      globalAttendance: '82%',
      faultsSummary: '(5/6 faltas)',
      classroom: 'Aula B2-301',
      riskLabel: 'RIESGO CRÍTICO DE INASISTENCIA',
      probableReason: 'Motivo probable: Dispositivo apagado o sin permisos BLE',
      initials: 'DP',
      isCritical: true,
    ),
    _UndetectedStudent(
      name: 'Lucía Beltrán Duarte',
      idCode: 'ID: 2022-4410',
      program: 'Ing. de Sistemas',
      semesterGroup: 'Semestre 6 • Grupo 302-B • Turno Matutino',
      globalAttendance: '92%',
      faultsSummary: '(1/6 faltas)',
      classroom: 'Aula B2-301',
      riskLabel: 'FUERA DEL RADIO DE AULA',
      probableReason: 'Motivo probable: Señal BLE débil (>15m del emisor)',
      initials: 'LB',
      isCritical: false,
    ),
    _UndetectedStudent(
      name: 'Andrés Felipe Silva',
      idCode: 'ID: 2021-1088',
      program: 'Ing. de Sistemas',
      semesterGroup: 'Semestre 6 • Grupo 302-B • Turno Matutino',
      globalAttendance: '86%',
      faultsSummary: '(3/6 faltas)',
      classroom: 'Aula B2-301',
      riskLabel: 'ALERTA DE ASISTENCIA',
      probableReason: 'Motivo probable: Bluetooth desactivado en el equipo',
      initials: 'AS',
      isCritical: false,
    ),
    _UndetectedStudent(
      name: 'Mariana Ortiz Gómez',
      idCode: 'ID: 2022-5102',
      program: 'Ing. de Software',
      semesterGroup: 'Semestre 6 • Grupo 302-B • Turno Matutino',
      globalAttendance: '95%',
      faultsSummary: '(1/6 faltas)',
      classroom: 'Aula B2-301',
      riskLabel: 'SIN RESPUESTA DE BALIZA',
      probableReason: 'Motivo probable: Modo ahorro de batería activo',
      initials: 'MO',
      isCritical: false,
    ),
    _UndetectedStudent(
      name: 'Juan Sebastián Rojas',
      idCode: 'ID: 2020-7741',
      program: 'Ing. de Sistemas',
      semesterGroup: 'Semestre 7 • Grupo 302-B • Turno Matutino',
      globalAttendance: '80%',
      faultsSummary: '(5/6 faltas)',
      classroom: 'Aula B2-301',
      riskLabel: 'RIESGO CRÍTICO DE INASISTENCIA',
      probableReason: 'Motivo probable: Sin conexión a red local del campus',
      initials: 'JR',
      isCritical: true,
    ),
  ];

  int _currentIndex = 0;
  double _dragOffsetX = 0.0;
  bool _isAnimatingOut = false;

  void _triggerCardSwipe({required bool isPresent}) {
    if (_isAnimatingOut) return;

    setState(() {
      _isAnimatingOut = true;
      _dragOffsetX = isPresent ? 420.0 : -420.0;
    });

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_currentIndex < _students.length - 1) {
        setState(() {
          _currentIndex++;
          _dragOffsetX = 0.0;
          _isAnimatingOut = false;
        });
      } else {
        // Al completar los 5 estudiantes, notifica y regresa al Radar (Pantalla 21)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Llamado manual completado (5 de 5 registrados)!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  void _handleUndo() {
    if (_currentIndex > 0 && !_isAnimatingOut) {
      setState(() {
        _currentIndex--;
        _dragOffsetX = 0.0;
      });
    }
  }

  void _handleAddJustificationNote() {
    final current = _students[_currentIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nota / justificante añadido para ${current.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStudent = _students[_currentIndex];
    final nextStudent = _currentIndex + 1 < _students.length
        ? _students[_currentIndex + 1]
        : null;

    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. TOP SAFE AREA & NAVIGATION HEADER BAR
            _buildTopHeader(context),

            // 2. MAIN CARD SWIPING STAGE (Stack of Cards + Side Hints)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _buildSwipingStage(
                  currentStudent: currentStudent,
                  nextStudent: nextStudent,
                ),
              ),
            ),

            // 3. BOTTOM CONTROLS (Swipe Hint + 4 Tactile Buttons + Table Link)
            _buildBottomControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final remainingCount = _currentIndex + 1;
    final total = _students.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Island Pill ("5 BLE")
          Center(
            child: Container(
              height: 28,
              width: 122,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: _systemRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.sensors, color: _primaryLight, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '5 BLE',
                        style: TextStyle(
                          color: _primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Navigation Bar (< Radar | Restantes: 1 de 5 | More)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: _primaryIndigo, size: 24),
                    Text(
                      'Radar',
                      style: TextStyle(
                        color: _primaryIndigo,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Restantes: ',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$remainingCount de $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.more_horiz,
                  color: AppTheme.textSecondary,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Segmented Progress Dots Bar (5 segments)
          Row(
            children: List.generate(total, (index) {
              final isCompletedOrCurrent = index <= _currentIndex;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index < total - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isCompletedOrCurrent
                        ? _primaryIndigo
                        : _surfaceControl,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Section Title & Course Meta
          const Row(
            children: [
              Icon(Icons.warning_rounded, color: _systemAmber, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Llamado Manual: 5 no detectados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              children: [
                const TextSpan(
                  text: 'Desliza para registrar o pulsa los botones • ',
                ),
                TextSpan(
                  text: widget.courseName,
                  style: const TextStyle(
                    color: _primaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipingStage({
    required _UndetectedStudent currentStudent,
    required _UndetectedStudent? nextStudent,
  }) {
    final double rotationAngle = (_dragOffsetX / 300).clamp(-0.35, 0.35);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // CARD 3: Back of the stack
        Transform.translate(
          offset: const Offset(0, 24),
          child: Transform.scale(
            scale: 0.88,
            child: Opacity(
              opacity: 0.35,
              child: Container(
                width: double.infinity,
                height: 440,
                decoration: BoxDecoration(
                  color: _surfaceElevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
        ),

        // CARD 2: Middle preview card (Lucía Beltrán Duarte)
        if (nextStudent != null)
          Transform.translate(
            offset: const Offset(0, 12),
            child: Transform.scale(
              scale: 0.94,
              child: Opacity(
                opacity: 0.72,
                child: Container(
                  width: double.infinity,
                  height: 455,
                  decoration: BoxDecoration(
                    color: _surfaceElevated,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: _surfaceControl,
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _surfaceElevated.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              nextStudent.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 14,
                              width: 120,
                              decoration: BoxDecoration(
                                color: _surfaceControl,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 10,
                              width: 180,
                              decoration: BoxDecoration(
                                color: _surfaceControl.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // CARD 1: ACTIVE FOREGROUND CARD (Draggable / Swipable)
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (_isAnimatingOut) return;
            setState(() {
              _dragOffsetX += details.delta.dx;
            });
          },
          onHorizontalDragEnd: (details) {
            if (_isAnimatingOut) return;
            if (_dragOffsetX > 95) {
              _triggerCardSwipe(isPresent: true);
            } else if (_dragOffsetX < -95) {
              _triggerCardSwipe(isPresent: false);
            } else {
              setState(() => _dragOffsetX = 0.0);
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: _isAnimatingOut ? 240 : 80),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(_dragOffsetX, 0.0)
              ..rotateZ(rotationAngle),
            transformAlignment: Alignment.center,
            child: _buildActiveForegroundCard(currentStudent),
          ),
        ),

        // Swipe Left Indicator Hint (AUSENTE)
        Positioned(
          left: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: _dragOffsetX < -20 ? 1.0 : 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _systemRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _systemRed, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _systemRed.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: _systemRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AUSENTE',
                    style: TextStyle(
                      color: _systemRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Swipe Right Indicator Hint (PRESENTE)
        Positioned(
          right: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: _dragOffsetX > 20 ? 1.0 : 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _tertiaryGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _tertiaryGreen, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _tertiaryGreen.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: _tertiaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PRESENTE',
                    style: TextStyle(
                      color: _tertiaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
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

  Widget _buildActiveForegroundCard(_UndetectedStudent student) {
    return Container(
      width: double.infinity,
      height: 475,
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Student Photo Canvas (~52% card height)
          Expanded(
            flex: 52,
            child: Container(
              width: double.infinity,
              color: _surfaceHigh,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Silueta/Avatar central de respaldo con gradiente oscuro
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 0.9,
                        colors: [
                          _primaryIndigo.withValues(alpha: 0.28),
                          _surfaceHigh,
                        ],
                      ),
                    ),
                    child: Center(
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: _surfaceControl,
                        child: Text(
                          student.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Gradiente scrim inferior y superior para lectura de badges
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                            _surfaceElevated,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top Meta Badges Floating on Photo
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    color: _primaryLight,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    student.idCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceControl.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                student.program,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Missing Beacon Badge ("Sin baliza BLE")
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _systemRed.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _systemRed.withValues(alpha: 0.6),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3.5,
                                backgroundColor: _systemRed,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Sin baliza BLE',
                                style: TextStyle(
                                  color: Colors.white,
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

                  // Photo Bottom Overlay Info ("RIESGO CRÍTICO DE INASISTENCIA")
                  Positioned(
                    bottom: 8,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _systemAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _systemAmber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        student.riskLabel,
                        style: const TextStyle(
                          color: _systemAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Card Body Content (~48% card height)
          Expanded(
            flex: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & Primary Tag
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              student.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.textTertiary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.semesterGroup,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Quick Metrics Bento Grid (2 columns)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _surfaceControl.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Asistencia global',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    student.globalAttendance,
                                    style: TextStyle(
                                      color: student.isCritical
                                          ? _systemRed
                                          : _tertiaryGreen,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      student.faultsSummary,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
                            color: _surfaceControl.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ubicación asignada',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.meeting_room_outlined,
                                    color: _primaryLight,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      student.classroom,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Offline / Reason Note Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceControl.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bluetooth_disabled,
                          color: _systemAmber,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            student.probableReason,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Swipe Instructions Visual Pill
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, color: AppTheme.textTertiary, size: 13),
              SizedBox(width: 4),
              Text(
                'Desliza izquierda: Ausente',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '•',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ),
              Text(
                'Desliza derecha: Presente',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: AppTheme.textTertiary, size: 13),
            ],
          ),
          const SizedBox(height: 10),

          // Tactile Floating Control Dock (4 Circular Buttons)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón 1: Undo / Rebobinar
                GestureDetector(
                  onTap: _handleUndo,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Icon(
                      Icons.replay,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),

                // Botón 2: AUSENTE (Coral Red Soft Glow)
                GestureDetector(
                  onTap: () => _triggerCardSwipe(isPresent: false),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _systemRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _systemRed, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _systemRed.withValues(alpha: 0.25),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: _systemRed,
                      size: 32,
                    ),
                  ),
                ),

                // Botón 3: PRESENTE (Neon Green Soft Glow)
                GestureDetector(
                  onTap: () => _triggerCardSwipe(isPresent: true),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _tertiaryGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _tertiaryGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _tertiaryGreen.withValues(alpha: 0.25),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: _tertiaryGreen,
                      size: 32,
                    ),
                  ),
                ),

                // Botón 4: Comentario / Justificante médico
                GestureDetector(
                  onTap: _handleAddJustificationNote,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      color: _primaryLight,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Alternative Action Link Footer ("O pulsa aquí para pasar a lista en tabla tradicional")
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'O pulsa aquí para pasar a lista en tabla tradicional',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.table_rows_outlined,
                  color: AppTheme.textSecondary,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UndetectedStudent {
  final String name;
  final String idCode;
  final String program;
  final String semesterGroup;
  final String globalAttendance;
  final String faultsSummary;
  final String classroom;
  final String riskLabel;
  final String probableReason;
  final String initials;
  final bool isCritical;

  const _UndetectedStudent({
    required this.name,
    required this.idCode,
    required this.program,
    required this.semesterGroup,
    required this.globalAttendance,
    required this.faultsSummary,
    required this.classroom,
    required this.riskLabel,
    required this.probableReason,
    required this.initials,
    required this.isCritical,
  });
}