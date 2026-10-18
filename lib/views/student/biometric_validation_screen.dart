import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/verificacion_result_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

class BiometricValidationScreen extends StatefulWidget {
  const BiometricValidationScreen({super.key});

  @override
  State<BiometricValidationScreen> createState() =>
      _BiometricValidationScreenState();
}

class _BiometricValidationScreenState extends State<BiometricValidationScreen>
    with SingleTickerProviderStateMixin {
  // Colores exactos del HTML de Stitch
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _secondaryBlue = Color(0xFF3E90FF); // secondary-container
  static const Color _secondaryLight = Color(0xFFAAC7FF); // secondary
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);

  late final AnimationController _pulseController;
  Timer? _otpTimer;
  Timer? _scanTimeout;

  int _timerVal = 26;
  String _currentToken = '8F42-99B1-A013';
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();

    // Controlador para el pulso orbital de fondo y el indicador NFC
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Temporizador en vivo para el Token Dinámico AES-256 (30s ciclo)
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerVal > 1) {
          _timerVal--;
        } else {
          _timerVal = 30;
          _currentToken = _generateRandomAesToken();
        }
      });
    });

    // Auto-disparo de verificación biométrica a los 400ms (igual que el script de Stitch)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _triggerVerification();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _otpTimer?.cancel();
    _scanTimeout?.cancel();
    super.dispose();
  }

  String _generateRandomAesToken() {
    const chars = '0123456789ABCDEF';
    final rand = Random();
    String block() =>
        List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${block()}-${block()}-${block()}';
  }

  void _triggerVerification() {
    _scanTimeout?.cancel();
    setState(() => _isScanning = true);

    _scanTimeout = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isScanning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final VerificacionResult? chairaData = authVM.usuarioActual;

    return Scaffold(
      backgroundColor: Colors.black, // bg-surface-oled
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    // 1. TOP NAVIGATION & INSTITUTIONAL BADGING
                    _buildTopHeader(context),
                    const SizedBox(height: 16),

                    // 2. DIGITAL APPLE WALLET PASS (CARNÉ DIGITAL INTELIGENTE)
                    _buildDigitalWalletPass(chairaData),
                    const SizedBox(height: 24),

                    // 3. FACE ID INTERACTIVE BIOMETRIC SCANNER
                    _buildBiometricScannerSection(),
                    const SizedBox(height: 28),

                    // 4. INTERACTIVE CONTROLS ("Revalidar Credencial")
                    _buildRevalidateButton(),
                    const SizedBox(height: 16),

                    // Barra separadora sutil inferior
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: const Color(0xFF353437).withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 20),

                    // 5. SECURITY ENDORSEMENT FOOTER
                    _buildSecurityFooter(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botón Cerrar ('X') -> Vuelve a Pantalla 5 (Portal Estudiante)
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceControl,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),

        // Pill Central: "UDLA SECURE ACCESS"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock,
                color: _primaryLight,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'UDLA SECURE ACCESS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // Indicador Derecho NFC con punto verde pulsante
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceControl,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
                  _pulseController,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _tertiaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.contactless,
                color: _tertiaryGreen,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigitalWalletPass(VerificacionResult? data) {
    final nombre = data?.nombre ?? 'Usuario';
    final cedula = data?.cedula ?? data?.documentoConsultado ?? '—';
    final programa = data?.programa ?? 'Ingeniería de Sistemas';
    final rol = (data?.tipoUsuario ?? 'DOCENTE').toUpperCase();
    final fotoBytes = data?.imagenBytes;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceElevated,
            AppTheme.surfaceElevated,
            Color(0xFF141416),
          ],
        ),
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
      child: Stack(
        children: [
          // Brillo superior especular en el borde de la tarjeta
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _primaryIndigo.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Encabezado del Carné: Logo + Universidad + Badge "ACTIVO"
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
                              color: AppTheme.surfaceControl,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.school,
                              color: _primaryLight,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UNIVERSIDAD DE LA AMAZONIA',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'CARNÉ DIGITAL INTELIGENTE',
                                  style: TextStyle(
                                    color: _primaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
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
                        color: _tertiaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
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
                            'ACTIVO',
                            style: TextStyle(
                              color: _tertiaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Foto + Nombre + Rol + Carrera + ID Institucional
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceControl,
                            borderRadius: BorderRadius.circular(14),
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
                                  size: 34,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: _tertiaryGreen,
                              size: 15,
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
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryIndigo.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  rol,
                                  style: const TextStyle(
                                    color: _primaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                programa,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                              children: [
                                const TextSpan(text: 'ID Institucional: '),
                                TextSpan(
                                  text: cedula,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 16),

                // 3. Caja de Token Dinámico AES-256 + Temporizador en vivo
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceControl,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.qr_code_2,
                            color: _secondaryBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Token Dinámico AES-256',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentToken,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: _systemAmber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_timerVal}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Footer dentro del Carné: "Acerca al lector del torniquete o aula"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
                        _pulseController,
                      ),
                      child: const Icon(
                        Icons.contactless_outlined,
                        color: _primaryLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Acerca al lector del torniquete o aula',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
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
    );
  }

  Widget _buildBiometricScannerSection() {
    final ringColor = _isScanning ? _primaryIndigo : _tertiaryGreen;

    return Column(
      children: [
        // Círculo interactivo con halo difuso y anillo de progreso
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo orbital difuso de fondo (como en la imagen de Stitch)
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryIndigo.withValues(alpha: 0.12),
                  ),
                ),
              ),

              // Círculo interior oscuro con borde brillante (Verde o Índigo)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor,
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: _isScanning
                      ? const Icon(
                          Icons.face,
                          color: _primaryLight,
                          size: 36,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Título dinámico: "¡Identidad Verificada!" o "Autenticando con Face ID..."
        Text(
          _isScanning
              ? 'Autenticando con Face ID...'
              : '¡Identidad Verificada!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        // Subtítulo dinámico
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Text(
            _isScanning
                ? 'Verificando rasgos faciales y token criptográfico'
                : 'Acceso concedido a torniquetes Campus Centro',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Pill de Ubicación: "Campus Principal • Edificio Central Aulas"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: _secondaryLight,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'Campus Principal • Edificio Central Aulas',
                style: TextStyle(
                  color: Color(0xFFE4E2E4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevalidateButton() {
    return ElevatedButton(
      onPressed: _isScanning ? null : _triggerVerification,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryIndigo,
        disabledBackgroundColor: _primaryIndigo.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 8,
        shadowColor: _primaryIndigo.withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isScanning ? Icons.hourglass_top_rounded : Icons.refresh,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _isScanning ? 'Escaneando...' : 'Revalidar Credencial',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user,
            color: AppTheme.textTertiary,
            size: 16,
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Cifrado integral con Apple Secure Enclave • UDLA IT v4.18',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}