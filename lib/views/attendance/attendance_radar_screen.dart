import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/curso_model.dart';
import '../../models/sesion_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/radar_viewmodel.dart';
import 'manual_rollcall_screen.dart';

class AttendanceRadarScreen extends StatefulWidget {
  final Curso curso;

  const AttendanceRadarScreen({super.key, required this.curso});

  String get courseTitle => [
        curso.nombre,
        if (curso.aula.isNotEmpty) curso.aula,
      ].join(' • ');

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

  late final RadarViewModel _vm;
  int _selectedFilter = 0; // 0: Todos, 1: Detectados, 2: Ausentes

  /// Repinta la cuenta atrás del llamado. El viewmodel solo avisa cuando pasa
  /// algo (una baliza, un cierre), no cada vez que corre el segundero.
  Timer? _cuentaAtras;

  bool get _isRadarActive => _vm.escaneando;

  @override
  void initState() {
    super.initState();
    _vm = RadarViewModel()..addListener(_alCambiarElRadar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar());

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

    _cuentaAtras = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _vm.sesion == null) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cuentaAtras?.cancel();
    _vm.removeListener(_alCambiarElRadar);
    _vm.dispose();
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Abre la clase y empieza a escuchar. El viewmodel es quien comprueba el
  /// horario, la geocerca y los permisos.
  Future<void> _arrancar() async {
    await _vm.iniciar(widget.curso, widget.curso.docenteUid);
    if (!mounted) return;
    final error = _vm.error;
    if (error != null) _avisar(error);
  }

  void _alCambiarElRadar() {
    if (!mounted) return;
    if (_vm.escaneando) {
      if (!_sweepController.isAnimating) _sweepController.repeat();
    } else {
      _sweepController.stop();
    }
    setState(() {});
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.error),
    );
  }

  /// Detener cierra el llamado: es lo que hace que cuente en los
  /// porcentajes. Con el llamado ya vencido, el botón abre otro.
  Future<void> _toggleRadarState() async {
    if (_vm.ocupado) return;
    if (_isRadarActive) {
      final confirmado = await _confirmarCierre();
      if (!confirmado || !mounted) return;
      await _vm.detener();
      if (mounted) Navigator.pop(context);
      return;
    }
    await _arrancar();
  }

  Future<bool> _confirmarCierre() async {
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surfaceElevated,
        title: const Text(
          '¿Cerrar el llamado?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se deja de escuchar y el llamado queda cerrado antes de tiempo. '
          '${_vm.detectados} de ${_vm.totalInscritos} quedarán como '
          'asistencia; el resto cuenta como falta.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir escuchando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cerrar el llamado',
              style: TextStyle(color: _systemRed),
            ),
          ),
        ],
      ),
    );
    return cerrar ?? false;
  }

  /// Tocar a un estudiante lo marca a mano, para cuando el BLE no lo oyó.
  Future<void> _marcarAMano(_RadarStudentItem item) async {
    if (_vm.sesion == null) {
      _avisar('Abre la clase antes de marcar asistencia.');
      return;
    }
    if (item.isPresent) return;
    final fila = _vm.lista.firstWhere((f) => f.inscrito.nombre == item.name);
    final ok = await _vm.marcarManual(fila.inscrito);
    if (!mounted) return;
    if (!ok) {
      _avisar(_vm.error ?? 'No se pudo marcar la asistencia.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} marcado a mano'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _onManualRollcallTap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManualRollcallScreen(radar: _vm)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estudiantes = _vm.lista.map(_aItem).toList();
    final filteredStudents = estudiantes.where((s) {
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

                      if (_vm.error != null) ...[
                        _buildAvisoError(_vm.error!),
                        const SizedBox(height: 16),
                      ],

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

                      // Un punto por cada estudiante que el radar ya oyó.
                      Positioned(
                        top: 28,
                        right: 64,
                        child: _buildBlipDetectado(0, 32),
                      ),
                      Positioned(
                        bottom: 36,
                        left: 52,
                        child: _buildBlipDetectado(1, 28),
                      ),
                      Positioned(
                        top: 44,
                        left: 46,
                        child: _buildBlipDetectado(2, 28),
                      ),
                      Positioned(
                        bottom: 30,
                        right: 46,
                        child: _buildBlipDetectado(3, 28),
                      ),
                      Positioned(
                        top: 108,
                        right: 22,
                        child: _buildBlipDetectado(4, 24),
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

          // Cuántos van detectados de los inscritos y qué tan fuerte es la
          // señal del que mejor se oye.
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
                      children: [
                        Text(
                          '${_vm.detectados} / ${_vm.totalInscritos}',
                          style: const TextStyle(
                            color: _tertiaryFixed,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Detectados$_porcentajeDetectado',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.radar,
                            color: _primaryIndigo, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _mejorSenal,
                          style: const TextStyle(
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
                    widthFactor: _fraccionDetectada,
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

  /// Qué parte de los inscritos lleva detectada el radar, de 0 a 1.
  double get _fraccionDetectada {
    final total = _vm.totalInscritos;
    return total == 0 ? 0 : _vm.detectados / total;
  }

  String get _porcentajeDetectado {
    if (_vm.totalInscritos == 0) return '';
    return ' (${(_fraccionDetectada * 100).round()}%)';
  }

  /// La señal del estudiante que mejor se oye ahora mismo.
  String get _mejorSenal {
    final rssis = _vm.lista
        .map((f) => f.rssi)
        .whereType<int>()
        .toList();
    if (rssis.isEmpty) return 'Sin señal todavía';
    return 'Mejor señal: ${_calidad(rssis.reduce((a, b) => a > b ? a : b))}';
  }

  /// Un punto del radar por cada estudiante ya detectado.
  Widget _buildBlipDetectado(int n, double size, {bool grande = false}) {
    final iniciales = _inicialesDetectado(n);
    if (iniciales == null) return SizedBox(width: size, height: size);
    return _buildStudentBlip(
      initials: iniciales,
      size: size,
      bgColor: grande ? _tertiaryGreen.withValues(alpha: 0.25) : null,
      showCheck: true,
    );
  }

  /// Iniciales del detectado número [n], o null si todavía no hay tantos.
  String? _inicialesDetectado(int n) {
    final detectados = _vm.lista.where((i) => i.detectado).toList();
    if (n >= detectados.length) return null;
    return _iniciales(detectados[n].inscrito.nombre);
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  _RadarStudentItem _aItem(InscritoEnRadar fila) {
    final asistencia = fila.asistencia;
    final identificacion = fila.inscrito.cedula ?? fila.inscrito.email ?? '';
    return _RadarStudentItem(
      name: fila.inscrito.nombre,
      idAndProgram: identificacion,
      signalDetail: _detalleSenal(fila),
      timeText: asistencia == null ? 'Sin registro' : _hora(asistencia.hora),
      initials: _iniciales(fila.inscrito.nombre),
      isPresent: fila.detectado,
      absentIcon: fila.detectado ? null : Icons.wifi_tethering_off,
    );
  }

  String _detalleSenal(InscritoEnRadar fila) {
    final asistencia = fila.asistencia;
    if (asistencia == null) {
      // Se le oye, pero el servidor todavía no deja registrarlo porque él no
      // ha firmado su presencia. Se reintenta solo con cada anuncio suyo.
      if (_vm.esperandoFirma(fila.inscrito.clave)) {
        return 'Se le oye, falta que firme en su celular';
      }
      return _isRadarActive ? 'Buscando baliza BLE...' : 'Sin detectar';
    }
    if (asistencia.metodo == MetodoAsistencia.manual) {
      return asistencia.estado == EstadoAsistencia.ausente
          ? 'Marcado ausente a mano'
          : 'Marcado a mano por ti';
    }
    final tarde = asistencia.estado == EstadoAsistencia.tarde;
    final senal = fila.rssi == null ? '' : ' • ${_calidad(fila.rssi!)} señal';
    return '${tarde ? 'Llegó tarde' : 'Detectado por BLE'}$senal';
  }

  /// De -40 dBm (pegado al docente) a -100 dBm (al límite del aula).
  static String _calidad(int rssi) {
    final porcentaje = ((rssi + 100) * 100 / 60).clamp(0, 100).round();
    return '$porcentaje%';
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Widget _buildAvisoError(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _systemRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _systemRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _systemRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.35,
              ),
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
    return Stack(
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
    );
  }

  /// Qué dice la tira de estado: que no hay llamado, lo que queda de ventana,
  /// o que ya se cerró y lo único que queda es el llamado manual.
  String get _estadoDelLlamado {
    final sesion = _vm.sesion;
    if (sesion == null) return 'La clase no está abierta.';
    if (_vm.llamadoVencido) {
      return 'El llamado se cerró. Marca a mano a quien falte.';
    }
    final restante = _vm.restanteDelLlamado ?? Duration.zero;
    return 'Quedan ${_mmss(restante)} de llamado, hasta las '
        '${_hora(sesion.fin)}';
  }

  /// La cuenta atrás, en "07:32". El llamado nunca pasa de diez minutos, así
  /// que no hace falta contemplar las horas.
  static String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Estado del llamado: lo que queda de ventana y cuántos van.
  Widget _buildAlternativeMethodsStrip() {
    final sesion = _vm.sesion;
    final vencido = _vm.llamadoVencido;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            sesion == null
                ? Icons.lock_clock
                : vencido
                    ? Icons.timer_off_outlined
                    : Icons.schedule,
            color: sesion == null
                ? AppTheme.textTertiary
                : vencido
                    ? _systemAmber
                    : _tertiaryGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _estadoDelLlamado,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${_vm.detectados}/${_vm.totalInscritos}',
            style: const TextStyle(
              color: _tertiaryGreen,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
              _buildFilterTab(
                index: 0,
                label: 'Todos',
                count: '(${_vm.totalInscritos})',
              ),
              _buildFilterTab(
                index: 1,
                label: 'Detectados',
                count: '(${_vm.detectados})',
                dotColor: _tertiaryGreen,
              ),
              _buildFilterTab(
                index: 2,
                label: 'Ausentes',
                count: '(${_vm.faltantes})',
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
            children: [
              Text(
                'ESTUDIANTES EN AULA (${_vm.totalInscritos} INSCRITOS)',
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
      onTap: () => _marcarAMano(student),
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

  /// Con el llamado vencido el botón no "reanuda" nada: abre otro llamado de
  /// diez minutos, y el radar empieza de cero.
  String get _textoDelBotonPrincipal {
    if (_isRadarActive) return 'Detener Radar';
    return _vm.sesion == null ? 'Abrir el llamado' : 'Abrir otro llamado';
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
                      _textoDelBotonPrincipal,
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
