import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/verificacion_result_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

class BleBeaconScreen extends StatefulWidget {
  final String courseName;
  final String classroom;

  const BleBeaconScreen({
    super.key,
    this.courseName = 'Ingeniería de Software II',
    this.classroom = 'Aula 301 (Edif. B)',
  });

  @override
  State<BleBeaconScreen> createState() => _BleBeaconScreenState();
}

class _BleBeaconScreenState extends State<BleBeaconScreen>
    with TickerProviderStateMixin {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryDeep = Color(0xFF3B39A0);
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemRed = Color(0xFFFF453A);

  late final AnimationController _rippleController;
  late final AnimationController _coreBreathingController;
  late final AnimationController _liveDotController;

  Timer? _countdownTimer;
  int _totalSeconds = 4 * 60 + 59; // 04:59 inicial como en el script
  bool _isDisconnecting = false;
  bool _isStopped = false;

  @override
  void initState() {
    super.initState();

    // Controlador para los 3 anillos expansivos del radar (3.4s infinite)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();

    // Controlador para la respiración del núcleo central (3s ease-in-out infinite)
    _coreBreathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Controlador para el punto vivo parpadeante (1.4s infinite)
    _liveDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Temporizador de 5 minutos en reversa
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_totalSeconds <= 0) {
        timer.cancel();
        setState(() {});
        return;
      }
      setState(() {
        _totalSeconds--;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rippleController.dispose();
    _coreBreathingController.dispose();
    _liveDotController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    if (_isStopped) return '--:--';
    final minutes = (_totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleStopTransmission() async {
    if (_isDisconnecting || _isStopped) {
      Navigator.pop(context);
      return;
    }

    _countdownTimer?.cancel();
    setState(() => _isDisconnecting = true);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isDisconnecting = false;
      _isStopped = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Según el Roadmap: 20 (Emisión BLE) -> Finalizar clase -> 15 (Detalle Curso)
    Navigator.pop(context);
  }

  void _onOpenRadarScreen() {
    // Según el Roadmap: 20 (Emisión BLE) -> Ver alumnos detectados -> 21 (Radar de Asistencia)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ir a Pantalla 21: Radar de Asistencia en Tiempo Real'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final VerificacionResult? chairaData = authVM.verificacionResult;

    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. TOP APP BAR & INSTITUTIONAL HEADER
            _buildTopHeader(),

            // 2. CENTRAL HERO: BLE RADAR + CRYPTOGRAPHIC IDENTITY CAPSULE
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    // Escenario del Radar con ondas concéntricas y contador
                    _buildRadarRippleStage(),
                    const SizedBox(height: 12),

                    // Textos de estado bajo el radar
                    _buildStatusHeadings(),
                    const SizedBox(height: 20),

                    // Cápsula de Identidad Criptográfica y Telemetría BLE
                    _buildCryptographicIdentityCapsule(chairaData),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 3. BOTTOM ACTION FOOTER ("Detener Emisión")
            _buildBottomFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Island Pill: "BLE 2.4GHz Activo"
          Center(
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _surfaceOled,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
                      _liveDotController,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _primaryIndigo,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _primaryIndigo, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.settings_remote,
                    color: _primaryLight,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'BLE 2.4GHz Activo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Fila: Chip "UDLA • Campus Seguro" + Botón Cerrar ('X')
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _surfaceControl.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: _primaryIndigo,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'UDLA • Campus Seguro',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _handleStopTransmission,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _surfaceControl.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título "Transmisión Segura" + Pill de Asignatura y Aula
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transmisión Segura',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceElevated.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 4,
                            backgroundColor: _tertiaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.courseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.classroom,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadarRippleStage() {
    return GestureDetector(
      onTap: _onOpenRadarScreen,
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo de fondo difuso
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryIndigo.withValues(alpha: 0.16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryIndigo.withValues(alpha: 0.25),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),

            // 3 Anillos expansivos desfasados (ripple-ring-1, 2, 3)
            if (!_isStopped) ...[
              _buildExpandingRing(delayFraction: 0.0, maxOpacity: 0.40),
              _buildExpandingRing(delayFraction: 0.33, maxOpacity: 0.30),
              _buildExpandingRing(delayFraction: 0.66, maxOpacity: 0.22),
            ],

            // Anillos fijos tipo sonar
            Container(
              width: 236,
              height: 236,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Núcleo central resonante con animación de respiración
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.035).animate(
                CurvedAnimation(
                  parent: _coreBreathingController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                width: 164,
                height: 164,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_primaryIndigo, _primaryDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryIndigo.withValues(alpha: 0.55),
                      blurRadius: 34,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surfaceOled.withValues(alpha: 0.86),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.podcasts,
                        color: _primaryLight,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formattedTime,
                        style: TextStyle(
                          color: _totalSeconds == 0
                              ? _systemRed
                              : _isStopped
                                  ? AppTheme.textSecondary
                                  : Colors.white,
                          fontSize: 30,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'VENTANA TOKEN',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
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

  Widget _buildExpandingRing({
    required double delayFraction,
    required double maxOpacity,
  }) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, _) {
        final rawProgress = (_rippleController.value + delayFraction) % 1.0;
        final scale = 0.72 + (rawProgress * 0.96); // 0.72 -> 1.68 como en CSS
        final opacity = (1.0 - rawProgress) * maxOpacity;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _primaryIndigo.withValues(
                  alpha: opacity.clamp(0.0, 1.0),
                ),
                width: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeadings() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
                _liveDotController,
              ),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isStopped ? AppTheme.textTertiary : _tertiaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isStopped
                  ? 'Baliza desconectada'
                  : 'Emitiendo baliza de asistencia...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Mantén la app abierta cerca del receptor del aula para validar tu presencia sin contacto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Acceso rápido hacia la Pantalla 21 (Radar de Asistencia Docente) según el Roadmap
        GestureDetector(
          onTap: _onOpenRadarScreen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryIndigo.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primaryIndigo.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar, color: _primaryLight, size: 15),
                SizedBox(width: 6),
                Text(
                  'Ver alumnos en Radar BLE',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: _primaryLight, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCryptographicIdentityCapsule(VerificacionResult? data) {
    final nombre = data?.nombre ?? 'Jhojan Fernando Leon';
    final cedula = data?.cedula ?? data?.documentoConsultado ?? '1117554321';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fila de identidad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _tertiaryGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: _primaryLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estudiante Acreditado',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'ID',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    cedula,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),

          // Fila de Telemetría (UUID Beacon Aula & Potencia Señal RSSI)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceControl.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UUID Beacon Aula',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '4A89-BLE-301',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
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
                    color: _surfaceControl.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Potencia Señal (RSSI)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '-54 dBm',
                            style: TextStyle(
                              color: _tertiaryGreen,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(Excelente)',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
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
          const SizedBox(height: 12),

          // Verified Geofence Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _tertiaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _tertiaryGreen.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: _tertiaryGreen,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Geocerca Aula 301 Verificada',
                      style: TextStyle(
                        color: _tertiaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'AES-256',
                  style: TextStyle(
                    color: _tertiaryGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontFamily: 'monospace',
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

  Widget _buildBottomFooter() {
    final bool isNormalState = !_isDisconnecting && !_isStopped;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GestureDetector(
        onTap: _handleStopTransmission,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: isNormalState
                ? _systemRed.withValues(alpha: 0.15)
                : _surfaceControl.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNormalState
                  ? _systemRed.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isDisconnecting) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Desconectando BLE...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (_isStopped) ...[
                const Icon(
                  Icons.check,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Baliza Finalizada',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.stop_circle_outlined,
                  color: _systemRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Detener Emisión',
                  style: TextStyle(
                    color: _systemRed,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}