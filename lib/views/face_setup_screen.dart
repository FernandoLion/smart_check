import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/verificacion_result_model.dart';
import '../utils/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';
import 'teacher/teacher_home_screen.dart';
class FaceSetupScreen extends StatefulWidget {
  const FaceSetupScreen({super.key});

  @override
  State<FaceSetupScreen> createState() => _FaceSetupScreenState();
}

class _FaceSetupScreenState extends State<FaceSetupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _laserController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _isScanning = false;
  bool _scanCompleted = false;

  // Colores extraídos del HTML de Stitch
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _surfaceLowest = Color(0xFF0E0E10);

  @override
  void initState() {
    super.initState();

    // Animación de barrido láser (2.8s infinite alternate como en Stitch)
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    // Animación de pulso para el óvalo guía (3s ease-in-out infinite)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleScanFace() async {
    setState(() => _isScanning = true);

    // Simulamos la generación del vector criptográfico en el Secure Enclave
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _scanCompleted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Vector biométrico registrado con éxito en el dispositivo!'),
        backgroundColor: AppTheme.success,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Navegamos al Login (o al Paso 3 si tienes una pantalla más)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _handleSkip() {
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Leemos los datos verificados de Chairá desde el ViewModel (MVVM)
    final authViewModel = context.watch<AuthViewModel>();
    final VerificacionResult? chairaData =
        authViewModel.usuarioActual ?? authViewModel.verificacionResult;

    return Scaffold(
      backgroundColor: Colors.black, // bg-surface-oled
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER DE NAVEGACIÓN Y PROGRESO (PASO 2 DE 3: 66%)
            _buildNavigationHeader(context),

            // 2. CONTENIDO PRINCIPAL SCROLLABLE
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta 1: Identidad Verificada Chairá
                    _buildVerifiedIdentityCard(chairaData),
                    const SizedBox(height: 20),

                    // Título y subtítulo Configuración Facial
                    const Text(
                      'Configuración Facial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Registra tu rostro para generar la clave biométrica requerida para la toma de asistencia offline y anti-suplantación.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tarjeta 2: Viewport de Cámara / Face ID Frame
                    _buildCameraViewport(),
                    const SizedBox(height: 16),

                    // Tarjeta 3: Nota de Seguridad Offline Secure Enclave
                    _buildSecurityNoteCard(),
                  ],
                ),
              ),
            ),

            // 3. FOOTER DE ACCIONES (Escanear Rostro / Hacer esto más tarde)
            _buildBottomActionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón "< Registro"
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: AppTheme.secondary,
                      size: 24,
                    ),
                    Text(
                      'Registro',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Pill "UDLA SECURE"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceControl.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 3,
                      backgroundColor: _primaryIndigo,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'UDLA SECURE',
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
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso: PASO 2 DE 3: BIOMETRÍA (66%)
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PASO 2 DE 3: BIOMETRÍA',
                style: TextStyle(
                  color: _primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '66%',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceControl,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.66,
              child: Container(
                decoration: BoxDecoration(
                  color: _primaryIndigo,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryIndigo.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedIdentityCard(VerificacionResult? data) {
    final nombre = data?.nombre ?? 'Jhojan Fernando Leon Claros';
    final cedula = data?.cedula ?? data?.documentoConsultado ?? '1117554321';
    final rol = (data?.tipoUsuario ?? 'DOCENTE').toUpperCase();
    final fotoBytes = data?.imagenBytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Badge "DATOS CHAIRÁ VERIFICADOS" + "Sincronizado"
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
                    color: _tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _tertiaryGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: _tertiaryGreen,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'DATOS CHAIRÁ VERIFICADOS',
                          style: TextStyle(
                            color: _tertiaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sincronizado',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila del Usuario: Avatar + Nombre + ID + Rol
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tertiaryGreen, width: 1.5),
                      image: fotoBytes != null
                          ? DecorationImage(
                              image: MemoryImage(fotoBytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: fotoBytes == null
                        ? const Icon(
                            Icons.person,
                            color: AppTheme.textSecondary,
                            size: 28,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: _tertiaryGreen,
                        size: 14,
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
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'ID: $cedula',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryIndigo.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _primaryIndigo.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            rol,
                            style: const TextStyle(
                              color: _primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
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
        ],
      ),
    );
  }

  Widget _buildCameraViewport() {
    return AspectRatio(
      aspectRatio: 4 / 4.1,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fondo gradiente sutil
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _primaryIndigo.withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Línea láser animada (sube y baja del 12% al 88%)
            AnimatedBuilder(
              animation: _laserController,
              builder: (context, child) {
                return Positioned(
                  left: 32,
                  right: 32,
                  top: 30 + (_laserController.value * 260),
                  child: Opacity(
                    opacity: 0.25 + (0.6 * _laserController.value),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            _primaryLight,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryLight.withValues(alpha: 0.8),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Contenido del HUD (Top Badges, Marco Central y Chip Inferior)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Status inside HUD: "Sensor TrueDepth" & "30 FPS"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam,
                              color: _primaryLight,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Sensor TrueDepth',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 3,
                              backgroundColor: _tertiaryGreen,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '30 FPS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Marco Biométrico Central (Esquinas + Óvalo + Constelación)
                  SizedBox(
                    width: 224,
                    height: 224,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 4 Esquinas estilo Apple Face ID
                        const Positioned(
                          top: 0,
                          left: 0,
                          child: _CornerBracket(isTop: true, isLeft: true),
                        ),
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: _CornerBracket(isTop: true, isLeft: false),
                        ),
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          child: _CornerBracket(isTop: false, isLeft: true),
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: _CornerBracket(isTop: false, isLeft: false),
                        ),

                        // Óvalo Guía con animación de pulso y puntos biométricos
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: SizedBox(
                            width: 176,
                            height: 192,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Anillo exterior punteado simulado
                                Container(
                                  width: 176,
                                  height: 192,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: _scanCompleted
                                          ? _tertiaryGreen
                                          : _primaryLight.withValues(
                                              alpha: 0.35,
                                            ),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                // Anillo interior
                                Container(
                                  width: 144,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: _primaryLight.withValues(
                                        alpha: 0.18,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _scanCompleted
                                        ? Icons.check_circle_outline
                                        : Icons.face,
                                    size: 64,
                                    color: _scanCompleted
                                        ? _tertiaryGreen
                                        : _primaryLight.withValues(alpha: 0.3),
                                  ),
                                ),
                                // Puntos de la constelación facial
                                _buildConstellationDot(top: 48, left: 40),
                                _buildConstellationDot(top: 48, right: 40),
                                _buildConstellationDot(top: 88),
                                _buildConstellationDot(bottom: 48, left: 48),
                                _buildConstellationDot(bottom: 48, right: 48),
                                _buildConstellationDot(bottom: 32, isWide: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chip inferior dentro de la cámara: "Rostro centrado • Iluminación óptima"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _tertiaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isScanning
                                ? 'Generando vector biométrico...'
                                : 'Rostro centrado • Iluminación óptima',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildConstellationDot({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool isWide = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: isWide ? 8 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: _primaryLight,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: _primaryLight.withValues(alpha: 0.8),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNoteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surfaceControl,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.enhanced_encryption,
              color: _primaryIndigo,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Validación Offline Anti-Fraude',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.lock_outline,
                      color: AppTheme.textSecondary,
                      size: 14,
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'El algoritmo no almacena fotos; genera un vector criptográfico local protegido en el Secure Enclave del dispositivo para validar asistencia sin internet.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(color: Colors.black),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón Primario: "Escanear Rostro" (#5E5CE6)
          ElevatedButton(
            onPressed: _isScanning ? null : _handleScanFace,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryIndigo,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 6,
              shadowColor: _primaryIndigo.withValues(alpha: 0.4),
            ),
            child: _isScanning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.document_scanner_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Escanear Rostro',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          // Botón Secundario: "Hacer esto más tarde"
          TextButton(
            onPressed: _isScanning ? null : _handleSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              minimumSize: const Size.fromHeight(38),
            ),
            child: const Text(
              'Hacer esto más tarde',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget auxiliar para dibujar las 4 esquinas redondeadas del marco Face ID
class _CornerBracket extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerBracket({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const borderSide = BorderSide(color: Color(0xFF5E5CE6), width: 3.5);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(16) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
          bottomLeft:
              !isTop && isLeft ? const Radius.circular(16) : Radius.zero,
          bottomRight:
              !isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
        ),
        border: Border(
          top: isTop ? borderSide : BorderSide.none,
          bottom: !isTop ? borderSide : BorderSide.none,
          left: isLeft ? borderSide : BorderSide.none,
          right: !isLeft ? borderSide : BorderSide.none,
        ),
      ),
    );
  }
}