import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../models/curso_model.dart';
import '../../services/rostro_service.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/face_verification_viewmodel.dart';

/// Comprueba con la cámara frontal que delante del celular hay una persona
/// de verdad, antes de dejarla emitir la baliza.
///
/// Devuelve `true` por [Navigator.pop] si se verificó, y null si se canceló
/// o no se pudo.
class FaceVerificationScreen extends StatefulWidget {
  final Curso curso;

  const FaceVerificationScreen({super.key, required this.curso});

  String get courseTitle => '${curso.nombre} - Grupo ${curso.grupo}';
  String get professorName => 'Docente: ${curso.docenteNombre}';
  String get classroom => curso.aula;

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

  final _rostros = RostroService();
  final _vm = FaceVerificationViewModel();

  CameraController? _camara;

  /// Se descartan los fotogramas que llegan mientras ML Kit trabaja: si se
  /// encolan, la vista se traba y acaba cayéndose.
  bool _procesando = false;
  bool _saliendo = false;
  String? _errorDeCamara;

  bool get _isValidated => _vm.verificado;

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

    _vm.addListener(_alCambiar);
    _encenderLaCamara();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {});
    if (_vm.verificado) _salirVerificado();
  }

  Future<void> _encenderLaCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        throw CameraException('sin-camara', 'Este celular no tiene cámara.');
      }
      final frontal = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      final control = CameraController(
        frontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await control.initialize();
      if (!mounted) {
        await control.dispose();
        return;
      }
      setState(() => _camara = control);
      _vm.empezar();
      await control.startImageStream(_alLlegarFotograma);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _errorDeCamara = _mensajeDeCamara(e));
    }
  }

  static String _mensajeDeCamara(CameraException e) {
    if (e.code.toLowerCase().contains('denied')) {
      return 'Sin permiso de cámara no se puede verificar tu rostro. '
          'Dáselo a SmartCheck desde los ajustes del celular.';
    }
    return 'No se pudo abrir la cámara: ${e.description ?? e.code}';
  }

  Future<void> _alLlegarFotograma(CameraImage imagen) async {
    if (_procesando || _vm.terminado || !mounted) return;
    _procesando = true;
    try {
      final entrada = _comoEntradaDeMlKit(imagen);
      if (entrada != null) {
        final tamano = Size(
          imagen.width.toDouble(),
          imagen.height.toDouble(),
        );
        _vm.alVer(await _rostros.analizar(entrada, tamano));
      }
    } catch (_) {
      // Un fotograma ilegible no es motivo para tumbar la pantalla.
    } finally {
      _procesando = false;
    }
  }

  InputImage? _comoEntradaDeMlKit(CameraImage imagen) {
    final camara = _camara;
    if (camara == null || imagen.planes.isEmpty) return null;
    final rotacion = InputImageRotationValue.fromRawValue(
      camara.description.sensorOrientation,
    );
    final formato = InputImageFormatValue.fromRawValue(imagen.format.raw);
    if (rotacion == null || formato == null) return null;
    return InputImage.fromBytes(
      bytes: imagen.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(imagen.width.toDouble(), imagen.height.toDouble()),
        rotation: rotacion,
        format: formato,
        bytesPerRow: imagen.planes.first.bytesPerRow,
      ),
    );
  }

  /// Se deja ver un momento el "Listo, eres tú" antes de seguir a la baliza.
  Future<void> _salirVerificado() async {
    if (_saliendo) return;
    _saliendo = true;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _vm.removeListener(_alCambiar);
    _vm.dispose();
    _camara?.dispose();
    _rostros.cerrar();
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
              // Volver a empezar con otro gesto. (Aquí había una linterna,
              // pero la cámara frontal del celular no tiene flash.)
              GestureDetector(
                onTap: _camara == null ? null : _vm.empezar,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _surfaceElevated.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: _camara == null ? AppTheme.textTertiary : Colors.white,
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
                    // Lo que ve la cámara frontal, recortado al círculo.
                    Positioned.fill(child: _buildVistaDeLaCamara()),

                    // Malla de puntos 3D TrueDepth
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FaceIdMeshPainter(),
                      ),
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
                left: 10,
                right: 10,
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
                        Flexible(
                          child: Text(
                            _vm.instruccion,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                icon: _vm.paso == PasoVerificacion.encuadrando
                    ? Icons.zoom_out_map
                    : Icons.check_circle,
                label: _vm.paso == PasoVerificacion.encuadrando
                    ? 'Acércate'
                    : 'Distancia óptima',
              ),
              const SizedBox(width: 8),
              _buildTelemetryPill(
                icon: _vm.reto == Reto.parpadeo
                    ? Icons.remove_red_eye_outlined
                    : Icons.screen_rotation_alt_outlined,
                label: _vm.reto == Reto.parpadeo
                    ? 'Gesto: parpadear'
                    : 'Gesto: girar la cabeza',
              ),
              const SizedBox(width: 8),
              _buildTelemetryPill(
                icon: _isValidated ? Icons.verified : Icons.timelapse,
                label: _isValidated
                    ? 'Prueba de vida: OK'
                    : 'Prueba de vida: ${(_vm.progreso * 100).round()}%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Lo que ve la cámara, o el motivo por el que no se ve nada.
  Widget _buildVistaDeLaCamara() {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _errorDeCamara == null
              ? Icon(
                  Icons.person,
                  size: 150,
                  color: _primaryLight.withValues(alpha: 0.12),
                )
              : Text(
                  _errorDeCamara!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
        ),
      );
    }
    final vista = camara.value.previewSize;
    // La vista viene en horizontal: se gira y se recorta para llenar el
    // círculo sin deformar la cara, que es lo que mide ML Kit.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: vista?.height ?? 1,
        height: vista?.width ?? 1,
        child: CameraPreview(camara),
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
                              'Sin verificar el rostro no se emite baliza',
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