import 'package:flutter/material.dart';
import '../../../models/student_subject_model.dart';
import '../../../utils/app_theme.dart';
import 'biometric_validation_screen.dart';
import "../attendance/ble_beacon_screen.dart";
class AttendanceDetailScreen extends StatefulWidget {
  final StudentSubjectModel? subject;

  const AttendanceDetailScreen({
    super.key,
    this.subject,
  });

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  // Colores exactos del HTML de Stitch
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryFixed = Color(0xFFE2DFFF); // primary-fixed
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryFixed = Color(0xFF6CFF82); // tertiary-fixed
  static const Color _calendarGreen = Color(0xFF30D158);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _justifiedBlue = Color(0xFF0A84FF);
  static const Color _secondaryBlue = Color(0xFF3E90FF);

  int _selectedCalendarView = 0; // 0: Vista Mes, 1: Historial Completo

  void _handleBleCheckIn() {
    // Notificación flotante idéntica al script JS de Stitch
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 24, right: 24),
        duration: const Duration(milliseconds: 2200),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _tertiaryGreen.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: _tertiaryFixed, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Conectando con baliza de Aula 301...',
                  style: TextStyle(
                    color: _tertiaryFixed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Opcionalmente abrimos la validación biométrica tras conectar con la baliza
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BleBeaconScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.subject?.code ?? 'SIS-402';
    final name = widget.subject?.name ?? 'Ingeniería de Software II';
    final attendance = widget.subject?.attendancePercent ?? 82;

    return Scaffold(
      backgroundColor: Colors.black, // bg-surface-oled
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. TOP NAVIGATION HEADER BAR ("< Mis Asignaturas")
                _buildNavigationHeader(context),

                // 2. MAIN SCROLLABLE CONTENT CANVAS
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
                    children: [
                      // Course Title & Metadata Cluster
                      _buildCourseTitleSection(code: code, name: name),
                      const SizedBox(height: 20),

                      // 2. PROMINENT WARNING PANEL: TERMÓMETRO DE RIESGO
                      _buildRiskThermometerCard(attendance: attendance),
                      const SizedBox(height: 20),

                      // 3. MONTHLY ATTENDANCE CALENDAR (MARZO 2025)
                      _buildMonthlyCalendarCard(),
                      const SizedBox(height: 22),

                      // 4. RECENT ATTENDANCE LOG SNIPPETS
                      _buildRecentAttendanceLogs(),
                    ],
                  ),
                ),
              ],
            ),

            // 5. STICKY BOTTOM ACTION CONTAINER (Iniciar Asistencia BLE)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomAction(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Action Button ("< Mis Asignaturas") -> Vuelve a Pantalla 5
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left,
                  color: _primaryIndigo,
                  size: 26,
                ),
                Text(
                  'Mis Asignaturas',
                  style: TextStyle(
                    color: _primaryIndigo,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Trailing Action Icons (Calendario y Más opciones)
          Row(
            children: [
              _buildCircleIconButton(Icons.event_available_outlined),
              const SizedBox(width: 8),
              _buildCircleIconButton(Icons.more_horiz),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(
        icon,
        color: AppTheme.textSecondary,
        size: 18,
      ),
    );
  }

  Widget _buildCourseTitleSection({
    required String code,
    required String name,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: _primaryIndigo.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: _primaryFixed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '• Grupo 302-B',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.surfaceControl,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppTheme.textSecondary,
                size: 13,
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(text: 'Docente: '),
                  TextSpan(
                    text: 'Jhojan F. Leon',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskThermometerCard({required int attendance}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _systemAmber.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del Termómetro
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _systemAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: _systemAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Termómetro de Riesgo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Reglamento Académico Estudiantil',
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
              // Pill "Te quedan 2 fallas"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _systemAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _systemAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: _systemAmber),
                    SizedBox(width: 5),
                    Text(
                      'Te quedan 2\nfallas',
                      style: TextStyle(
                        color: _systemAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Métrica Principal: "82% Válida" y "4 / 6 fallas máx. permitidas"
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
                    '$attendance%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Válida',
                    style: TextStyle(
                      color: _tertiaryFixed,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: '4',
                      style: TextStyle(
                        color: _systemAmber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: ' / 6 fallas máx. permitidas'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de progreso segmentada en 4 zonas
          Container(
            height: 12,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F21),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                // Zona 1: Segura (50%)
                Expanded(
                  flex: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _tertiaryGreen,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _tertiaryGreen.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Zona 2: Advertencia (18%)
                Expanded(
                  flex: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _systemAmber,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _systemAmber.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Zona 3: Margen restante (15%)
                Expanded(
                  flex: 15,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceControl,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _systemAmber.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Zona 4: Umbral de reprobación (17%)
                Expanded(
                  flex: 17,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _systemRed.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Etiquetas bajo la barra segmentada
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 fallas',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                'Límite crítico: 6 fallas (Acuerdo 014)',
                style: TextStyle(
                  color: _systemAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Reprobación',
                style: TextStyle(color: _systemRed, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),

          // Grilla de 4 contadores rápidos (Presentes, Fallas, Justificada, Restantes)
          Row(
            children: [
              Expanded(
                child: _buildCounterTile(
                  dotColor: _tertiaryGreen,
                  value: '18',
                  valueColor: Colors.white,
                  label: 'Presentes',
                  labelColor: AppTheme.textSecondary,
                  bgColor: AppTheme.surfaceControl.withValues(alpha: 0.7),
                  borderColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCounterTile(
                  dotColor: _systemRed,
                  value: '4',
                  valueColor: _systemRed,
                  label: 'Fallas',
                  labelColor: AppTheme.textSecondary,
                  bgColor: AppTheme.surfaceControl.withValues(alpha: 0.7),
                  borderColor: _systemAmber.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCounterTile(
                  dotColor: _secondaryBlue,
                  value: '1',
                  valueColor: Colors.white,
                  label: 'Justificada',
                  labelColor: AppTheme.textSecondary,
                  bgColor: AppTheme.surfaceControl.withValues(alpha: 0.7),
                  borderColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCounterTile(
                  dotColor: _systemAmber,
                  value: '2',
                  valueColor: _systemAmber,
                  label: 'Restantes',
                  labelColor: _systemAmber,
                  bgColor: _systemAmber.withValues(alpha: 0.1),
                  borderColor: _systemAmber.withValues(alpha: 0.35),
                  isBoldLabel: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterTile({
    required Color dotColor,
    required String value,
    required Color valueColor,
    required String label,
    required Color labelColor,
    required Color bgColor,
    required Color borderColor,
    bool isBoldLabel = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 4, backgroundColor: dotColor),
              const SizedBox(width: 5),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: isBoldLabel ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendarCard() {
    // Estructura exacta de las 6 semanas de Marzo 2025 del HTML de Stitch
    final List<_CalendarDay> calendarDays = const [
      // Semana 1: Feb 24-28 (dim) / Mar 1-2
      _CalendarDay('24', _DayType.otherMonth),
      _CalendarDay('25', _DayType.otherMonth),
      _CalendarDay('26', _DayType.otherMonth),
      _CalendarDay('27', _DayType.otherMonth),
      _CalendarDay('28', _DayType.otherMonth),
      _CalendarDay('1', _DayType.weekend),
      _CalendarDay('2', _DayType.weekend),
      // Semana 2
      _CalendarDay('3', _DayType.normal),
      _CalendarDay('4', _DayType.present),
      _CalendarDay('5', _DayType.normal),
      _CalendarDay('6', _DayType.present),
      _CalendarDay('7', _DayType.normal),
      _CalendarDay('8', _DayType.weekend),
      _CalendarDay('9', _DayType.weekend),
      // Semana 3
      _CalendarDay('10', _DayType.normal),
      _CalendarDay('11', _DayType.present),
      _CalendarDay('12', _DayType.normal),
      _CalendarDay('13', _DayType.absent),
      _CalendarDay('14', _DayType.normal),
      _CalendarDay('15', _DayType.weekend),
      _CalendarDay('16', _DayType.weekend),
      // Semana 4
      _CalendarDay('17', _DayType.normal),
      _CalendarDay('18', _DayType.present),
      _CalendarDay('19', _DayType.normal),
      _CalendarDay('20', _DayType.absentLatest),
      _CalendarDay('21', _DayType.normal),
      _CalendarDay('22', _DayType.weekend),
      _CalendarDay('23', _DayType.weekend),
      // Semana 5
      _CalendarDay('24', _DayType.normal),
      _CalendarDay('25', _DayType.present),
      _CalendarDay('26', _DayType.normal),
      _CalendarDay('27', _DayType.justified),
      _CalendarDay('28', _DayType.today),
      _CalendarDay('29', _DayType.weekend),
      _CalendarDay('30', _DayType.weekend),
      // Semana 6
      _CalendarDay('31', _DayType.weekend),
      _CalendarDay('1', _DayType.otherMonth),
      _CalendarDay('2', _DayType.otherMonth),
      _CalendarDay('3', _DayType.otherMonth),
      _CalendarDay('4', _DayType.otherMonth),
      _CalendarDay('5', _DayType.otherMonth),
      _CalendarDay('6', _DayType.otherMonth),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Selector segmentado: Vista Mes / Historial Completo
          Container(
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceControl,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCalendarView = 0),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedCalendarView == 0
                            ? AppTheme.surfaceElevated
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Vista Mes',
                        style: TextStyle(
                          color: _selectedCalendarView == 0
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: _selectedCalendarView == 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCalendarView = 1),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedCalendarView == 1
                            ? AppTheme.surfaceElevated
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Historial Completo',
                        style: TextStyle(
                          color: _selectedCalendarView == 1
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: _selectedCalendarView == 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Navegación del Mes: "Marzo 2025" + "1er Periodo" + Flechas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Marzo 2025',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryIndigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '1er Periodo',
                      style: TextStyle(
                        color: _primaryIndigo,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildSmallNavCircle(Icons.chevron_left),
                  const SizedBox(width: 6),
                  _buildSmallNavCircle(Icons.chevron_right),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Días de la semana (L M M J V S D)
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _WeekdayLabel('L'),
                _WeekdayLabel('M'),
                _WeekdayLabel('M'),
                _WeekdayLabel('J'),
                _WeekdayLabel('V'),
                _WeekdayLabel('S'),
                _WeekdayLabel('D'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Cuadrícula de días
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              return _buildDayCell(calendarDays[index]);
            },
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),

          // Leyenda del Calendario (Presente, Falla, Justificada, Hoy)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(color: _calendarGreen, label: 'Presente'),
              _buildLegendItem(color: _systemRed, label: 'Falla'),
              _buildLegendItem(color: _justifiedBlue, label: 'Justificada'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _primaryIndigo, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Hoy',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallNavCircle(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: AppTheme.textSecondary, size: 18),
    );
  }

  Widget _buildDayCell(_CalendarDay item) {
    switch (item.type) {
      case _DayType.present:
        return Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _calendarGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _calendarGreen.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              item.day,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case _DayType.absent:
      case _DayType.absentLatest:
        return Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _systemRed,
              shape: BoxShape.circle,
              border: item.type == _DayType.absentLatest
                  ? Border.all(
                      color: _systemRed.withValues(alpha: 0.5),
                      width: 2.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: _systemRed.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              item.day,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case _DayType.justified:
        return Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _justifiedBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _justifiedBlue.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              item.day,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case _DayType.today:
        return Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primaryIndigo.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _primaryIndigo, width: 1.5),
            ),
            child: Text(
              item.day,
              style: const TextStyle(
                color: _primaryFixed,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case _DayType.otherMonth:
        return Center(
          child: Text(
            item.day,
            style: TextStyle(
              color: AppTheme.textTertiary.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        );
      case _DayType.weekend:
        return Center(
          child: Text(
            item.day,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 13,
            ),
          ),
        );
      case _DayType.normal:
        return Center(
          child: Text(
            item.day,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        );
    }
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecentAttendanceLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Últimos Registros de Clase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Ver todos (23)',
                  style: TextStyle(
                    color: _primaryIndigo,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Registro 1: Jueves 20 Mar (Ausente + Botón "Justificar")
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _systemRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close, color: _systemRed, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Jueves 20 Mar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
                            color: _systemRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Ausente',
                            style: TextStyle(
                              color: _systemRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sin detección BLE de baliza institucional • Aula 301',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Abriendo solicitud de justificación académica...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceControl,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Text(
                    'Justificar',
                    style: TextStyle(
                      color: _primaryIndigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Registro 2: Martes 18 Mar (Presente)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _tertiaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: _tertiaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Martes 18 Mar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _tertiaryGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Presente',
                            style: TextStyle(
                              color: _tertiaryFixed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'BLE validado (RSSI -58 dBm) + Geocerca Edificio B • 07:04 AM',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.verified_outlined,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Registro 3: Jueves 13 Mar (Justificada)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _justifiedBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: _justifiedBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Jueves 13 Mar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _justifiedBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Justificada',
                            style: TextStyle(
                              color: _justifiedBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Aprobada por Coordinación Académica • Rad. #49102',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.folder_outlined,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: GestureDetector(
        onTap: _handleBleCheckIn,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryIndigo, Color(0xFF7775F8)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: _primaryIndigo.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
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
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bluetooth_searching,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _tertiaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _primaryIndigo,
                                width: 2,
                              ),
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
                          const Row(
                            children: [
                              Text(
                                'Iniciar Asistencia BLE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.sensors,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transmisor baliza activo en Aula 301',
                            style: TextStyle(
                              color: _primaryFixed.withValues(alpha: 0.85),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

enum _DayType {
  otherMonth,
  weekend,
  normal,
  present,
  absent,
  absentLatest,
  justified,
  today,
}

class _CalendarDay {
  final String day;
  final _DayType type;
  const _CalendarDay(this.day, this.type);
}