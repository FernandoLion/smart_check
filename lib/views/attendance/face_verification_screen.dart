import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String courseTitle;
  final String professorName;
  final String classroom;

  const FaceVerificationScreen({
    super.key,
    this.courseTitle = 'Ing. de Software II - Grupo 302-B',
    this.professorName = 'Docente: Ana M. Pérez',
    this.classroom = 'Aula 301',
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with TickerProviderStateMixin {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);

  late final AnimationController _laserController;
  late final AnimationController _pulseController;
  Timer? _progressTimer;

  int _progress = 82;
  bool _isValidated = false;
  bool _flashlightOn = false;

  @override
  void initState() {
    super.initState();

    // Animación del barrido láser horizontal (2.4s infinite alternate)
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Animación de pulso para el anillo exterior (3s infinite)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Simulación del reconocimiento facial del 82% al 100% cada 400ms (igual que el script de Stitch)
    _progressTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return;
      setState(() {
        if (_progress < 100) {
          _progress += 2;
        } else {
          _isValidated = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _laserController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. TOP SECTION: DYNAMIC ISLAND, FLASHLIGHT & HEADER TELEMETRY
            _buildTopHeader(context),

            // 2. CENTER SECTION: BIOMETRIC SCANNING CIRCULAR CUTOUT & FACE ID HUD
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCenterBiometricScanner(context),
                ),
              ),
            ),

            // 3. BOTTOM SECTION: FROSTED GLASS CLASS CARD & CANCEL ACTION
            _buildBottomFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        children: [
          // iOS 18 Dynamic Island Pill with Active Telemetry
          Container(
            width: 210,
            height: 36,
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
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: _tertiaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.classroom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.bluetooth_searching,
                  color: _primaryIndigo,
                  size: 15,
                ),
                const Text(
                  'BLE Activo',
                  style: TextStyle(
                    color: _tertiaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Pill Buttons (Flashlight | Geocerca Validada | Info)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón Linterna frontal
              GestureDetector(
                onTap: () => setState(() => _flashlightOn = !_flashlightOn),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _flashlightOn
                        ? _primaryIndigo.withValues(alpha: 0.3)
                        : _surfaceElevated.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    _flashlightOn
                        ? Icons.flashlight_on
                        : Icons.flashlight_on_outlined,
                    color: _flashlightOn ? _primaryLight : Colors.white,
                    size: 20,
                  ),
                ),
              ),

              // Live Beacon Geofence Status Chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _surfaceElevated.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _tertiaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user,
                      color: _tertiaryGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Geocerca Validada • ${widget.classroom}',
                      style: const TextStyle(
                        color: _tertiaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Botón Info
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _surfaceElevated.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Verification Title & Course Hierarchy
          const Text(
            'Verificando Identidad para Asistencia...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mantén tu rostro dentro del marco • SIS-402 Ingeniería de Software II',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterBiometricScanner(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Master Circular Target Viewfinder (280x280)
        SizedBox(
          width: 280,
          height: 290,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Anillo exterior pulsante
              ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.02).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primaryIndigo.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Anillo verde intermedio
              Container(
                width: 272,
                height: 272,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _tertiaryGreen.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),

              // 4 Esquinas de precisión Face ID
              const Positioned(
                top: 4,
                left: 0,
                child: _ReticleCorner(isTop: true, isLeft: true),
              ),
              const Positioned(
                top: 4,
                right: 0,
                child: _ReticleCorner(isTop: true, isLeft: false),
              ),
              const Positioned(
                bottom: 4,
                left: 0,
                child: _ReticleCorner(isTop: false, isLeft: true),
              ),
              const Positioned(
                bottom: 4,
                right: 0,
                child: _ReticleCorner(isTop: false, isLeft: false),
              ),

              // Máscara Circular Central (260x260) con malla 3D TrueDepth y Nodos Faciales
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0E0E10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 30,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Malla de puntos 3D TrueDepth
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FaceIdMeshPainter(),
                      ),
                    ),

                    // Silueta sutil de rostro de fondo
                    Icon(
                      Icons.person,
                      size: 150,
                      color: _primaryLight.withValues(alpha: 0.12),
                    ),

                    // Nodos de seguimiento facial (Ojos, Nariz y Boca)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Nodos de los ojos
                        SizedBox(
                          width: 112,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildEyeNode(),
                              _buildEyeNode(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Nodo de la nariz
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _tertiaryGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _tertiaryGreen, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Barra de alineación de boca
                        Container(
                          width: 40,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: _primaryLight.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),

                    // Barra horizontal de escaneo láser (animate-laser)
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, _) {
                        return Positioned(
                          left: 24,
                          right: 24,
                          top: 30 + (_laserController.value * 195),
                          child: Opacity(
                            opacity: 0.25 + (_laserController.value * 0.65),
                            child: Container(
                              height: 2,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    _tertiaryGreen,
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF30D158),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Badge Flotante Inferior: Analizando % -> ¡Identidad Validada Con Éxito!
              Positioned(
                bottom: -6,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isValidated
                          ? _tertiaryContainer.withValues(alpha: 0.45)
                          : _surfaceElevated.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isValidated
                            ? _tertiaryGreen
                            : _primaryIndigo.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fingerprint,
                          color: _primaryIndigo,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isValidated
                              ? '¡Identidad Validada Con Éxito!'
                              : 'Analizando rasgos biométricos $_progress%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
        const SizedBox(height: 24),

        // Real-time Quality Telemetry Checklist (Horizontal Cupertino Pills)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTelemetryPill(
                icon: Icons.check_circle,
                label: 'Distancia óptima',
              ),
              const SizedBox(width: 8),
              _buildTelemetryPill(
                icon: Icons.check_circle,
                label: 'Iluminación adecuada',
              ),
              const SizedBox(width: 8),
              _buildTelemetryPill(
                icon: Icons.verified,
                label: 'Prueba de vida: OK',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEyeNode() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _primaryLight.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: _primaryIndigo, width: 1.5),
      ),
    );
  }

  Widget _buildTelemetryPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceControl.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _tertiaryGreen, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating Frosted Glass Course Metadata Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceElevated.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _primaryIndigo.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primaryIndigo.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.school,
                              color: _primaryIndigo,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.courseTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      color: AppTheme.textTertiary,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.professorName,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Text(
                        'Presencial',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alarm,
                            color: _systemAmber,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Ventana de tolerancia: 4 min restantes',
                              style: TextStyle(
                                color: _systemAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pin_drop_outlined,
                          color: AppTheme.textTertiary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sensor ${widget.classroom}',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Botón de acción: Cancelar Verificación (o Confirmar si ya terminó)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceControl.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, color: _systemRed, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cancelar Verificación',
                    style: TextStyle(
                      color: _systemRed,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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
}

/// Esquinas del visor Face ID
class _ReticleCorner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _ReticleCorner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Color(0xFFC2C1FF), width: 2.2);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(12) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(12) : Radius.zero,
          bottomLeft:
              !isTop && isLeft ? const Radius.circular(12) : Radius.zero,
          bottomRight:
              !isTop && !isLeft ? const Radius.circular(12) : Radius.zero,
        ),
        border: Border(
          top: isTop ? side : BorderSide.none,
          bottom: !isTop ? side : BorderSide.none,
          left: isLeft ? side : BorderSide.none,
          right: !isLeft ? side : BorderSide.none,
        ),
      ),
    );
  }
}

/// Pintor de la matriz de puntos 3D TrueDepth
class _FaceIdMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5E5CE6).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    const double spacing = 14.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}