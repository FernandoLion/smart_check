import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'ble_beacon_screen.dart';
class GeocercaSetupScreen extends StatefulWidget {
  final String blockAndRoom;
  final String facultySubtitle;

  const GeocercaSetupScreen({
    super.key,
    this.blockAndRoom = 'Bloque B2 - 301',
    this.facultySubtitle = 'Facultad de Ingeniería • Campus Principal',
  });

  @override
  State<GeocercaSetupScreen> createState() => _GeocercaSetupScreenState();
}

class _GeocercaSetupScreenState extends State<GeocercaSetupScreen>
    with TickerProviderStateMixin {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _mapDarkBg = Color(0xFF0B0B0D);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _secondaryBlue = Color(0xFF3E90FF); // secondary-container
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);

  late final AnimationController _pulseController;
  late final AnimationController _pingController;
  bool _strictMode = true;
  bool _is3DEnabled = false;

  @override
  void initState() {
    super.initState();

    // Animación de pulso de la geocerca (4s ease-in-out infinite)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Animación de onda expansiva (2.5s infinite)
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pingController.dispose();
    super.dispose();
  }

void _handleConfirmGeofence() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const BleBeaconScreen(),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. FULLSCREEN APPLE MAPS DARK CARTOGRAPHY CANVAS
          Positioned.fill(
            child: CustomPaint(
              painter: _CampusCartographyPainter(is3D: _is3DEnabled),
            ),
          ),

          // 2. GEOFENCE RADIAL PERIMETER & INTERACTIVE PIN MARKER (CENTERED AT ~38%)
          Align(
            alignment: const Alignment(0.0, -0.25),
            child: _buildGeofenceCenterMarker(),
          ),

          // 3. MAP FLOATING CONTROLS CLUSTER (Right Stack: 3D, Compass, My Location)
          Positioned(
            top: MediaQuery.of(context).padding.top + 96,
            right: 16,
            child: _buildRightMapControls(),
          ),

          // 4. TOP SAFE AREA & FLOATING PILL NAVIGATION BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildTopFloatingHeader(context),
            ),
          ),

          // 5. CUPERTINO FROSTED GLASS BOTTOM SHEET MODAL (~40% SCREEN)
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomSheetPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFloatingHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Dynamic Island Pill ("UDLA GPS")
          Container(
            width: 128,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: _tertiaryGreen),
                    SizedBox(width: 6),
                    Text(
                      'UDLA GPS',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.sensors, color: _primaryLight, size: 14),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Floating Pill Navigation Bar (< Clases | GPS Alta Precisión ±3m | Tune)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Navigation Pill
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceElevated.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left,
                        color: _primaryLight,
                        size: 18,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'Clases',
                        style: TextStyle(
                          color: _primaryLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Precision Pill Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _surfaceElevated.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: _tertiaryGreen),
                    SizedBox(width: 8),
                    Text(
                      'GPS Alta Precisión ±3m',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Campus Map Layers Toggle
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _surfaceElevated.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.tune,
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

  Widget _buildRightMapControls() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surfaceElevated.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _is3DEnabled = !_is3DEnabled),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      '3D',
                      style: TextStyle(
                        color: _is3DEnabled
                            ? _primaryLight
                            : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.explore_outlined,
                    color: _primaryLight,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mapa centrado en Bloque B2 - Aula 301'),
                duration: Duration(milliseconds: 900),
              ),
            );
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _surfaceElevated.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: _primaryIndigo,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeofenceCenterMarker() {
    return SizedBox(
      width: 260,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Onda exterior expansiva (ping-emitter)
          AnimatedBuilder(
            animation: _pingController,
            builder: (context, _) {
              final scale = 0.95 + (_pingController.value * 0.40);
              final opacity = (1.0 - _pingController.value) * 0.6;
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryIndigo.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              );
            },
          ),

          // Círculo principal de Geocerca pulsante (25m)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 0.92 + (_pulseController.value * 0.13);
              return Transform.scale(
                scale: scale,
                child: CustomPaint(
                  size: const Size(228, 228),
                  painter: _DashedGeofenceCirclePainter(
                    borderColor: _primaryIndigo,
                    fillStart: _primaryIndigo.withValues(alpha: 0.22),
                    fillEnd: _secondaryBlue.withValues(alpha: 0.08),
                  ),
                ),
              );
            },
          ),

          // Anillo interior concéntrico
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryIndigo.withValues(alpha: 0.05),
              border: Border.all(
                color: _primaryLight.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
          ),

          // Tooltip superior flotante: "Radio Activo: 25m"
          Positioned(
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceElevated.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: _tertiaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'Radio Activo: 25m',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pin Central Estilo Apple Maps Teardrop
          Transform.translate(
            offset: const Offset(0, -18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: -5,
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _primaryIndigo,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _primaryIndigo,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryIndigo.withValues(alpha: 0.65),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.meeting_room,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Sombra de contacto en el suelo
                Container(
                  width: 16,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: BoxDecoration(
            color: _surfaceElevated.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 40,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber Handle
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Sheet Header: Classroom Title & Faculty
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _primaryIndigo.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _primaryIndigo.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.domain,
                            color: _primaryIndigo,
                            size: 26,
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
                                      widget.blockAndRoom,
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
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tertiaryContainer.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _tertiaryGreen.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Verificado',
                                      style: TextStyle(
                                        color: _tertiaryGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.facultySubtitle,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
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
                    decoration: const BoxDecoration(
                      color: _surfaceControl,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bento Chips: Coordenadas & BLE + GPS
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceControl.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pin_drop_outlined,
                                color: AppTheme.textSecondary,
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'COORDENADAS',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            '1.6142° N, -75.6062° W',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceControl.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.wifi_tethering,
                                color: _tertiaryGreen,
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'BLE + GPS',
                                style: TextStyle(
                                  color: _tertiaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '25 m',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Señal Óptima',
                                style: TextStyle(
                                  color: _tertiaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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

              // Cupertino Switch Group: Modo Estricto de Aula
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surfaceControl.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.security,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Modo Estricto de Aula',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Valida presencia solo dentro del perímetro',
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
                    CupertinoSwitch(
                      value: _strictMode,
                      activeTrackColor: _tertiaryGreen,
                      onChanged: (val) => setState(() => _strictMode = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Primary Action Button: Confirmar Geocerca del Aula
              ElevatedButton(
                onPressed: _handleConfirmGeofence,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryIndigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 8,
                  shadowColor: _primaryIndigo.withValues(alpha: 0.45),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirmar Geocerca del Aula',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pintor del círculo punteado de la Geocerca
class _DashedGeofenceCirclePainter extends CustomPainter {
  final Color borderColor;
  final Color fillStart;
  final Color fillEnd;

  const _DashedGeofenceCirclePainter({
    required this.borderColor,
    required this.fillStart,
    required this.fillEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [fillStart, fillEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const int dashCount = 36;
    const double step = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * 0.55,
        false,
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor vectorial del mapa del Campus UDLA (replica el SVG del HTML de Stitch)
class _CampusCartographyPainter extends CustomPainter {
  final bool is3D;
  const _CampusCartographyPainter({required this.is3D});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fondo oscuro estilo Apple Maps
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0B0D),
    );

    // 2. Cuadrícula tenue de fondo (48x48)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final sx = size.width / 800.0;
    final sy = size.height / 1000.0;

    // 3. Zonas verdes / Plazoletas del Campus
    final grassFill = Paint()
      ..color = const Color(0xFF0A1A11).withValues(alpha: 0.85);
    final grassStroke = Paint()
      ..color = const Color(0xFF30D158).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void drawPolygon(List<Offset> pts) {
      final path = Path()
        ..addPolygon(
          pts.map((p) => Offset(p.dx * sx, p.dy * sy)).toList(),
          true,
        );
      canvas.drawPath(path, grassFill);
      canvas.drawPath(path, grassStroke);
    }

    drawPolygon(const [
      Offset(120, 240),
      Offset(280, 210),
      Offset(320, 380),
      Offset(150, 410),
    ]);
    drawPolygon(const [
      Offset(460, 190),
      Offset(710, 160),
      Offset(740, 360),
      Offset(500, 390),
    ]);
    drawPolygon(const [
      Offset(210, 580),
      Offset(430, 560),
      Offset(410, 740),
      Offset(180, 720),
    ]);

    // 4. Vías principales y senderos internos
    final roadPaint = Paint()
      ..color = const Color(0xFF252528)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawLine(
      Offset(0, 160 * sy),
      Offset(size.width, 120 * sy),
      roadPaint,
    );
    canvas.drawLine(
      Offset(710 * sx, 0),
      Offset(690 * sx, size.height),
      roadPaint,
    );

    final walkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(400 * sx, 100 * sy),
      Offset(400 * sx, 850 * sy),
      walkPaint,
    );
    canvas.drawLine(
      Offset(50 * sx, 460 * sy),
      Offset(750 * sx, 430 * sy),
      walkPaint,
    );
    canvas.drawLine(
      Offset(240 * sx, 210 * sy),
      Offset(240 * sx, 780 * sy),
      walkPaint,
    );

    // 5. Bloques y Edificios del Campus
    void drawBuilding({
      required Rect rect,
      required String title,
      String? subtitle,
      bool isSelected = false,
    }) {
      final scaledRect = Rect.fromLTWH(
        rect.left * sx,
        rect.top * sy,
        rect.width * sx,
        rect.height * sy,
      );
      final rrect = RRect.fromRectAndRadius(
        scaledRect,
        const Radius.circular(8),
      );

      final fill = Paint()
        ..color = isSelected
            ? const Color(0xFF242138)
            : const Color(0xFF1A1A1E);
      final border = Paint()
        ..color = isSelected
            ? const Color(0xFF5E5CE6)
            : Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.8 : 1.0;

      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, border);

      final tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8E8E93),
            fontSize: isSelected ? 11 : 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
          children: subtitle != null
              ? [
                  TextSpan(
                    text: '\n$subtitle',
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFC2C1FF)
                          : const Color(0xFF636366),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]
              : [],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          scaledRect.center.dx - tp.width / 2,
          scaledRect.center.dy - tp.height / 2,
        ),
      );
    }

    drawBuilding(
      rect: const Rect.fromLTWH(130, 230, 125, 65),
      title: 'BLOQUE A',
    );
    drawBuilding(
      rect: const Rect.fromLTWH(510, 215, 145, 85),
      title: 'BIBLIOTECA',
      subtitle: 'CENTRAL UDLA',
    );
    drawBuilding(
      rect: const Rect.fromLTWH(200, 345, 130, 52),
      title: 'BLOQUE B1',
    );
    drawBuilding(
      rect: const Rect.fromLTWH(490, 475, 160, 62),
      title: 'LABORATORIOS',
    );
    drawBuilding(
      rect: const Rect.fromLTWH(330, 380, 165, 85),
      title: 'BLOQUE B2',
      subtitle: 'AULA 301',
      isSelected: true,
    );
  }

  @override
  bool shouldRepaint(covariant _CampusCartographyPainter oldDelegate) =>
      oldDelegate.is3D != is3D;
}