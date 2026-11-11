import 'package:flutter/material.dart';

import '../../models/inscrito_model.dart';
import '../../models/sesion_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/botones_accesibles.dart';
import '../../viewmodels/radar_viewmodel.dart';

class ManualRollcallScreen extends StatefulWidget {
  /// El radar que abrió la clase: de ahí salen los no detectados y por ahí
  /// se escribe la asistencia.
  final RadarViewModel radar;

  const ManualRollcallScreen({super.key, required this.radar});

  String get courseName => radar.curso?.nombre ?? 'Clase';

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
  static const Color _primaryLight = Color(
    0xFFC2C1FF,
  ); // primary / primary-fixed-dim
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _azulJustificada = Color(0xFF0A84FF);

  /// Los que el BLE no oyó, congelados al entrar para que la lista no se
  /// mueva mientras el docente los pasa uno por uno.
  late final List<Inscrito> _pendientes = widget.radar.lista
      // Los que aún no tienen marca: al que ya se marcó (presente o
      // ausente) no se le vuelve a preguntar.
      .where((f) => !f.registrado)
      .map((f) => f.inscrito)
      .toList();

  late final List<_UndetectedStudent> _students = _pendientes
      .map(_aTarjeta)
      .toList();

  /// "3 no detectados", o "1 no detectado" cuando solo falta uno.
  String get _sinDetectar {
    final n = _students.length;
    return n == 1 ? '1 no detectado' : '$n no detectados';
  }

  _UndetectedStudent _aTarjeta(Inscrito inscrito) {
    final curso = widget.radar.curso;
    return _UndetectedStudent(
      name: inscrito.nombre,
      idCode: inscrito.cedula ?? inscrito.email ?? '',
      program: curso?.nombre ?? '',
      semesterGroup: curso == null
          ? ''
          : [
              if (curso.grupo.isNotEmpty) 'Grupo ${curso.grupo}',
              curso.periodo,
            ].join(' • '),
      globalAttendance: '—',
      faultsSummary: 'Ver detalle',
      classroom: curso?.aula ?? '',
      riskLabel: 'NO LO DETECTÓ EL RADAR',
      probableReason:
          'Motivo probable: Bluetooth apagado o sin permisos en su celular',
      initials: _iniciales(inscrito.nombre),
      isCritical: false,
    );
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  int _currentIndex = 0;
  double _dragOffsetX = 0.0;
  double _dragOffsetY = 0.0;
  bool _isAnimatingOut = false;

  /// Cuánto hay que arrastrar la tarjeta para que cuente.
  static const _umbralDelGesto = 95.0;

  /// Lo que marcaría la tarjeta si se suelta ahora, según hacia dónde va:
  /// arriba justificada, derecha presente, izquierda ausente.
  String? get _estadoDelGesto {
    final arriba = -_dragOffsetY;
    if (arriba > 20 && arriba > _dragOffsetX.abs()) {
      return EstadoAsistencia.justificada;
    }
    if (_dragOffsetX > 20) return EstadoAsistencia.presente;
    if (_dragOffsetX < -20) return EstadoAsistencia.ausente;
    return null;
  }

  /// Si ya se arrastró lo suficiente hacia ese lado.
  bool get _gestoCompleto =>
      _estadoDelGesto == EstadoAsistencia.justificada
          ? -_dragOffsetY > _umbralDelGesto
          : _dragOffsetX.abs() > _umbralDelGesto;

  /// El borde de la tarjeta se va pintando con el color de lo que marcaría
  /// (verde, rojo o azul) mientras se arrastra; quieta, null.
  Color? get _colorDelGesto {
    final estado = _estadoDelGesto;
    if (estado == null) return null;
    final avance = estado == EstadoAsistencia.justificada
        ? -_dragOffsetY
        : _dragOffsetX.abs();
    final color = switch (estado) {
      EstadoAsistencia.presente => _tertiaryGreen,
      EstadoAsistencia.ausente => _systemRed,
      _ => _azulJustificada,
    };
    return color.withValues(alpha: (avance / _umbralDelGesto).clamp(0.0, 1.0));
  }

  /// Marca la tarjeta de arriba con [estado] (presente, ausente o
  /// justificada) y pasa a la siguiente.
  void _triggerCardSwipe({required String estado}) {
    if (_isAnimatingOut || _students.isEmpty) return;

    final inscrito = _pendientes[_currentIndex];
    setState(() {
      _isAnimatingOut = true;
      if (estado == EstadoAsistencia.justificada) {
        _dragOffsetX = 0.0;
        _dragOffsetY = -700.0;
      } else {
        _dragOffsetX = estado == EstadoAsistencia.presente ? 420.0 : -420.0;
      }
    });
    _registrar(inscrito, estado);

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_currentIndex < _students.length - 1) {
        setState(() {
          _currentIndex++;
          _dragOffsetX = 0.0;
          _dragOffsetY = 0.0;
          _isAnimatingOut = false;
        });
      } else {
        final total = _students.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              total == 1
                  ? 'Llamado manual completado (1 estudiante)'
                  : 'Llamado manual completado ($total estudiantes)',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  Future<void> _registrar(Inscrito inscrito, String estado) async {
    final ok = await widget.radar.marcarManual(inscrito, estado: estado);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.radar.error ?? 'No se pudo guardar la asistencia.',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  /// Deshacer vuelve a la tarjeta anterior y borra la marca que se le
  /// guardó: queda sin marcar, como antes, hasta que se vuelva a pasar.
  Future<void> _handleUndo() async {
    if (_currentIndex == 0 || _isAnimatingOut) return;
    final anterior = _pendientes[_currentIndex - 1];
    setState(() {
      _currentIndex--;
      _dragOffsetX = 0.0;
      _dragOffsetY = 0.0;
    });
    final ok = await widget.radar.quitarMarcaManual(anterior);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.radar.error ?? 'No se pudo deshacer la marca.'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  Widget _buildTodosDetectados() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: _tertiaryGreen, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No queda nadie por marcar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'El radar ya detectó a todos los inscritos de esta clase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al radar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_students.isEmpty) {
      return Scaffold(
        backgroundColor: _surfaceOled,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopHeader(context),
              Expanded(child: _buildTodosDetectados()),
            ],
          ),
        ),
      );
    }
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
    final total = _students.length;
    // Sin nadie por marcar no hay "1 de 0".
    final remainingCount = total == 0 ? 0 : _currentIndex + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Bar (< Radar | Restantes: 1 de 5 | More)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Tocable(
                onTap: () => Navigator.pop(context),
                alineacion: AlignmentDirectional.centerStart,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: AppTheme.primaryTexto,
                      size: 24,
                    ),
                    Text(
                      'Radar',
                      style: TextStyle(
                        color: AppTheme.primaryTexto,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$remainingCount de $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Equilibra el "< Radar" de la izquierda.
              const SizedBox(width: 36),
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
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: _systemAmber, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Llamado Manual: $_sinDetectar',
                  style: const TextStyle(
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
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
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
                                fontSize: 13,
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
        // Derecha: presente. Izquierda: ausente. Arriba: justificada.
        GestureDetector(
          onPanUpdate: (details) {
            if (_isAnimatingOut) return;
            setState(() {
              _dragOffsetX += details.delta.dx;
              // Hacia abajo no hay nada que marcar.
              _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(
                -400.0,
                0.0,
              );
            });
          },
          onPanEnd: (_) {
            if (_isAnimatingOut) return;
            final estado = _estadoDelGesto;
            if (estado != null && _gestoCompleto) {
              _triggerCardSwipe(estado: estado);
            } else {
              setState(() {
                _dragOffsetX = 0.0;
                _dragOffsetY = 0.0;
              });
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: _isAnimatingOut ? 240 : 80),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translateByDouble(_dragOffsetX, _dragOffsetY, 0.0, 1.0)
              ..rotateZ(rotationAngle),
            transformAlignment: Alignment.center,
            child: _buildActiveForegroundCard(currentStudent),
          ),
        ),

      ],
    );
  }

  Widget _buildActiveForegroundCard(_UndetectedStudent student) {
    final gesto = _colorDelGesto;
    return Container(
      width: double.infinity,
      height: 475,
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: gesto ?? Colors.white.withValues(alpha: 0.08),
          width: gesto == null ? 1 : 3,
        ),
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
          // La foto es decorativa (las iniciales): se lleva la parte menor
          // del alto, para que los datos de abajo no se encojan en un
          // celular, donde la tarjeta no alcanza su alto completo.
          Expanded(
            flex: 34,
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
                    // Con poco alto (un celular) las etiquetas lo taparían:
                    // ahí se queda sin él; el nombre está justo abajo.
                    child: LayoutBuilder(
                      builder: (context, caja) => caja.maxHeight < 160
                          ? const SizedBox.shrink()
                          : Center(
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: _surfaceControl,
                                child: Text(
                                  student.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                        Expanded(
                          child: Column(
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
                                    Flexible(
                                      child: Text(
                                        student.idCode,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                  color: _surfaceControl.withValues(
                                    alpha: 0.85,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  student.program,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),
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
                                'Sin señal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
                          fontSize: 13,
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

          // 2. Los datos del estudiante: la mayor parte del alto.
          Expanded(
            flex: 66,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: // La tarjeta tiene alto fijo: si con letra grande el contenido no
                  // cabe, se reduce en proporción en vez de salirse.
                  LayoutBuilder(
                    builder: (context, caja) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: caja.maxWidth,
                          maxWidth: caja.maxWidth,
                          minHeight: caja.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name & Primary Tag
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                      fontSize: 13,
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
                                        color: _surfaceControl.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Asistencia global',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
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
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                        color: _surfaceControl.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ubicación asignada',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
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
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Un botón redondo del dock con su nombre debajo: con solo el ícono no
  /// todos saben qué hace cada uno.
  Widget _botonDelDock({
    required IconData icono,
    required String texto,
    required Color color,
    required double diametro,
    required VoidCallback onTap,
  }) {
    // El de deshacer es gris; los demás llevan el color de lo que marcan.
    final gris = color == AppTheme.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        label: texto,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: diametro,
                height: diametro,
                decoration: BoxDecoration(
                  color: gris ? _surfaceControl : color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: gris
                      ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                      : Border.all(color: color, width: 2),
                  boxShadow: gris || diametro < 64
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.25),
                            blurRadius: 18,
                          ),
                        ],
                ),
                child: Icon(icono, color: color, size: diametro / 2),
              ),
              const SizedBox(height: 6),
              // Con la letra grande se encoge antes que salirse.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  texto,
                  maxLines: 1,
                  style: TextStyle(
                    color: gris ? AppTheme.textSecondary : color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cómo se usa: cada botón dice lo que hace, y la tarjeta también
          // se puede deslizar.
          const Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            children: [
              Icon(Icons.swipe, color: AppTheme.textTertiary, size: 16),
              SizedBox(width: 6),
              Text(
                'Desliza a la derecha: presente · a la izquierda: ausente '
                '· arriba: justificada',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Los cuatro botones, cada uno con su nombre debajo.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _botonDelDock(
                  icono: Icons.replay,
                  texto: 'Deshacer',
                  color: AppTheme.textSecondary,
                  diametro: 48,
                  onTap: _handleUndo,
                ),
                _botonDelDock(
                  icono: Icons.close,
                  texto: 'Ausente',
                  color: _systemRed,
                  diametro: 64,
                  onTap: () =>
                      _triggerCardSwipe(estado: EstadoAsistencia.ausente),
                ),
                // No vino, pero con excusa: esa clase no se le cuenta.
                _botonDelDock(
                  icono: Icons.assignment_turned_in_outlined,
                  texto: 'Justificar',
                  color: _azulJustificada,
                  diametro: 56,
                  onTap: () =>
                      _triggerCardSwipe(estado: EstadoAsistencia.justificada),
                ),
                _botonDelDock(
                  icono: Icons.check,
                  texto: 'Presente',
                  color: _tertiaryGreen,
                  diametro: 64,
                  onTap: () =>
                      _triggerCardSwipe(estado: EstadoAsistencia.presente),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Volver al radar, que tiene la lista completa
          Tocable(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'O vuelve al radar, donde está la lista completa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
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
