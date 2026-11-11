import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../../models/curso_model.dart';
import '../../services/fotos_chaira.dart';
import '../../services/identidad_facial_service.dart';
import '../../services/rostro_service.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/face_verification_viewmodel.dart';

/// Comprueba con la cámara frontal que delante del celular está el dueño de
/// la cuenta, vivo, antes de dejarlo emitir la baliza.
///
/// Devuelve por [Navigator.pop] una [VerificacionFacial] si se verificó, y
/// null si se canceló o no se pudo.
class FaceVerificationScreen extends StatefulWidget {
  /// El curso del llamado, o null cuando se verifica para vincular el
  /// celular o para crear la cuenta.
  final Curso? curso;

  /// Con quién se compara la cara. Si no se da, con la del dueño de la
  /// sesión guardada en este celular; al registrarse, con la foto de Chairá
  /// del documento (ver [verificarRostroAlRegistrarse]).
  final IdentidadFacial? identidad;

  const FaceVerificationScreen({super.key, this.curso, this.identidad});

  bool get _esRegistro => identidad is IdentidadParaRegistro;

  String get courseTitle {
    if (curso != null) return '${curso!.nombre} - Grupo ${curso!.grupo}';
    return _esRegistro ? 'Crear tu cuenta' : 'Vincular este celular';
  }

  String get professorName {
    if (curso != null) return 'Docente: ${curso!.docenteNombre}';
    return _esRegistro
        ? 'Confirma que eres el dueño del documento'
        : 'Confirma que eres tú antes de atar tu cuenta';
  }

  /// El aula del curso, o lo que corresponda si no hay curso o no tiene
  /// aula escrita (nunca un texto vacío).
  String get classroom {
    if (curso == null) return 'Este celular';
    final aula = curso!.aula.trim();
    return aula.isEmpty ? 'Aula sin asignar' : aula;
  }

  bool get _sinAula => curso != null && curso!.aula.trim().isEmpty;

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemAmber = Color(0xFFFF9F0A);

  late final AnimationController _laserController;
  late final AnimationController _pulseController;

  final _rostros = RostroService();
  late final FaceVerificationViewModel _vm;

  CameraController? _camara;

  /// Se descartan los fotogramas que llegan mientras ML Kit trabaja: si se
  /// encolan, la vista se traba y acaba cayéndose.
  bool _procesando = false;
  bool _saliendo = false;
  bool _tomandoFoto = false;
  String? _errorDeCamara;

  /// Si la cámara no abrió porque le falta el permiso: se ofrece ir a los
  /// ajustes y, al volver, se intenta de nuevo.
  bool _sinPermisoDeCamara = false;

  /// Si fue a los ajustes con el botón. Solo entonces se reintenta al
  /// volver: el propio diálogo de permisos también pausa la app, y
  /// reintentar tras él lo volvería a pedir una y otra vez.
  bool _fueAAjustes = false;

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

    _vm = FaceVerificationViewModel(
      identidad: widget.identidad ?? _identidadDeLaSesion(),
      motivo: widget.curso != null
          ? MotivoVerificacion.asistencia
          : widget._esRegistro
          ? MotivoVerificacion.registro
          : MotivoVerificacion.cuenta,
    );
    _vm.addListener(_alCambiar);
    WidgetsBinding.instance.addObserver(this);
    _encenderLaCamara();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed &&
        _fueAAjustes &&
        _camara == null) {
      _fueAAjustes = false;
      setState(() {
        _errorDeCamara = null;
        _sinPermisoDeCamara = false;
      });
      _encenderLaCamara();
    }
  }

  IdentidadFacial _identidadDeLaSesion() {
    final auth = context.read<AuthViewModel>();
    final perfil = auth.perfil;
    return IdentidadEnCelular(
      uid: perfil?.uid ?? '',
      // La de la sesión si ya bajó; si no, se descarga ahora.
      fotoChaira: () async {
        final enMemoria = auth.usuarioActual?.imagenBytes;
        if (enMemoria != null) return enMemoria;
        final url = perfil?.fotoUrl;
        return url == null ? null : FotosChaira.compartida.foto(url);
      },
    );
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {});
    if (_vm.quiereFoto) _tomarFoto();
    if (_vm.terminado) _anotarParaCalibrar();
    if (_vm.verificado) _salirVerificado();
  }

  /// La similitud ya anotada de este intento, para no repetirla.
  double? _anotada;

  /// En depuración, cada comparación queda también en un archivo del
  /// celular: el log de MIUI se vacía enseguida, y estos números son los que
  /// sirven para calibrar los umbrales con caras reales. Solo números: ni
  /// fotos ni vectores. Se lee con
  /// `adb shell run-as com.example.smart_check cat cache/calibracion_rostro.txt`.
  void _anotarParaCalibrar() {
    final similitud = _vm.similitudCalculada;
    if (!kDebugMode || similitud == null || similitud == _anotada) return;
    _anotada = similitud;
    final resultado = _vm.verificado ? _vm.resultado!.name : 'fallido';
    File('${Directory.systemTemp.path}/calibracion_rostro.txt')
        .writeAsString(
          '${DateTime.now().toIso8601String()} motivo=${_vm.motivo.name} '
          'contra=${_vm.comparadaContra} resultado=$resultado '
          'similitud=${similitud.toStringAsFixed(3)}\n',
          mode: FileMode.append,
        )
        .ignore();
  }

  /// Al terminar el gesto se toma una foto en ese mismo instante y se
  /// compara con la del dueño. La foto se borra en cuanto se compara.
  Future<void> _tomarFoto() async {
    final camara = _camara;
    if (_tomandoFoto || camara == null) return;
    _tomandoFoto = true;
    XFile? foto;
    try {
      if (camara.value.isStreamingImages) await camara.stopImageStream();
      foto = await camara.takePicture();
      await _vm.compararFoto(foto.path);
    } catch (_) {
      await _vm.compararFoto('');
    } finally {
      _tomandoFoto = false;
      if (foto != null) {
        try {
          await File(foto.path).delete();
        } catch (_) {}
      }
    }
  }

  /// Otro intento, con otro gesto sorteado.
  Future<void> _reintentar() async {
    final camara = _camara;
    if (camara == null || _tomandoFoto) return;
    _vm.empezar();
    if (!camara.value.isStreamingImages) {
      await camara.startImageStream(_alLlegarFotograma);
    }
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
      setState(() {
        _errorDeCamara = _mensajeDeCamara(e);
        _sinPermisoDeCamara = _faltaPermiso(e);
      });
    } catch (_) {
      // Un celular sin el plugin de cámara (o un emulador raro) no debe
      // dejar la pantalla en blanco.
      if (!mounted) return;
      setState(() => _errorDeCamara = 'No se pudo abrir la cámara.');
    }
  }

  static bool _faltaPermiso(CameraException e) =>
      e.code.toLowerCase().contains('denied');

  static String _mensajeDeCamara(CameraException e) {
    if (_faltaPermiso(e)) {
      return 'Sin permiso de cámara no se puede verificar tu rostro. '
          'Dáselo a SmartCheck en los ajustes.';
    }
    return 'No se pudo abrir la cámara: ${e.description ?? e.code}';
  }

  Future<void> _alLlegarFotograma(CameraImage imagen) async {
    if (_procesando || _vm.terminado || !mounted) return;
    _procesando = true;
    try {
      final entrada = _comoEntradaDeMlKit(imagen);
      if (entrada != null) {
        final tamano = Size(imagen.width.toDouble(), imagen.height.toDouble());
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
    final resultado = _vm.resultado;
    if (!mounted || resultado == null) return;
    Navigator.pop<VerificacionFacial>(context, (
      resultado: resultado,
      similitud: _vm.similitudCalculada,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.removeListener(_alCambiar);
    _vm.identidad?.cerrar();
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
              child: Center(child: _buildCenterBiometricScanner(context)),
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
          // En un llamado, recuerda que la señal no sale hasta verificar.
          if (widget.curso != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isValidated ? Icons.bluetooth : Icons.bluetooth_disabled,
                    color: _isValidated
                        ? _tertiaryGreen
                        : AppTheme.textTertiary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _isValidated
                          ? 'Listo para enviar tu asistencia'
                          : 'Señal de asistencia en espera',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              // Volver a empezar con otro gesto. (Aquí había una linterna,
              // pero la cámara frontal del celular no tiene flash.)
              IconButton(
                onPressed: _camara == null ? null : _reintentar,
                tooltip: 'Volver a empezar',
                style: IconButton.styleFrom(
                  backgroundColor: _surfaceElevated,
                  disabledBackgroundColor: _surfaceElevated,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  minimumSize: const Size(48, 48),
                ),
                icon: Icon(
                  Icons.refresh,
                  color: _camara == null ? AppTheme.textTertiary : Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                        Flexible(
                          child: Text(
                            widget.curso == null
                                ? (widget._esRegistro
                                      ? 'Registro de cuenta'
                                      : 'Vinculación de celular')
                                // La ubicación la comprueba después la
                                // pantalla de la señal, no esta.
                                : widget._sinAula
                                ? widget.classroom
                                : 'Aula: ${widget.classroom}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _tertiaryGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Del ancho del botón de la izquierda, para que el aula quede
              // centrada.
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            widget.curso == null
                ? 'Verificando tu identidad...'
                : 'Verificando Identidad para Asistencia...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mantén tu rostro dentro del círculo',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// Lo que se le dice debajo del círculo: el paso que toca, el motivo por
  /// el que falló o por qué no se ve la cámara.
  String get _textoDeInstruccion {
    final error = _errorDeCamara;
    if (error != null) return error;
    // En depuración se ve la similitud, para calibrar los umbrales con
    // caras reales.
    if (kDebugMode && _vm.similitudCalculada != null) {
      return '${_vm.instruccion} '
          '(${_vm.similitudCalculada!.toStringAsFixed(2)})';
    }
    return _vm.instruccion;
  }

  Color get _colorDeInstruccion {
    if (_errorDeCamara != null) return _systemAmber;
    if (_isValidated) return _tertiaryGreen;
    if (_vm.paso == PasoVerificacion.fallido) return AppTheme.errorTexto;
    return Colors.white;
  }

  Widget _buildCenterBiometricScanner(BuildContext context) {
    return LayoutBuilder(
      builder: (context, espacio) {
        // El círculo se achica en celulares bajos para que la instrucción y
        // el botón de reintentar se vean sin desplazar.
        final diametro = espacio.maxHeight.isFinite
            ? (espacio.maxHeight - 190).clamp(170.0, 280.0)
            : 280.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: diametro,
                child: FittedBox(child: _buildCirculo()),
              ),
              const SizedBox(height: 16),

              // La instrucción, grande y con el color del estado. TalkBack
              // la lee cada vez que cambia.
              Semantics(
                liveRegion: true,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _colorDeInstruccion,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                  child: Text(_textoDeInstruccion, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 16),
              _buildAccionOEstado(),
            ],
          ),
        );
      },
    );
  }

  /// El visor circular de 280: anillos, esquinas, cámara y barrido.
  Widget _buildCirculo() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                  child: CustomPaint(painter: _FaceIdMeshPainter()),
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
        ],
      ),
    );
  }

  /// Debajo de la instrucción: un botón claro cuando hay algo que hacer
  /// (reintentar, dar el permiso) y, mientras tanto, cómo va cada prueba.
  Widget _buildAccionOEstado() {
    if (_errorDeCamara != null) {
      if (!_sinPermisoDeCamara) return const SizedBox.shrink();
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          // Al volver de los ajustes se intenta abrir la cámara otra vez
          // (ver didChangeAppLifecycleState).
          onPressed: () {
            _fueAAjustes = true;
            Geolocator.openAppSettings();
          },
          icon: const Icon(Icons.settings, size: 20),
          label: const Text('Abrir ajustes'),
        ),
      );
    }
    if (_vm.paso == PasoVerificacion.fallido) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _camara == null ? null : _reintentar,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Intentar de nuevo'),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTelemetryPill(
          // Solo hay distancia que juzgar cuando hay una cara.
          icon: switch (_vm.paso) {
            PasoVerificacion.buscando => Icons.face_outlined,
            PasoVerificacion.encuadrando => Icons.zoom_out_map,
            _ => Icons.check_circle,
          },
          label: switch (_vm.paso) {
            PasoVerificacion.buscando => 'Buscando tu cara',
            PasoVerificacion.encuadrando => 'Acércate',
            _ => 'Distancia correcta',
          },
        ),
        _buildTelemetryPill(
          icon: _vm.reto == Reto.parpadeo
              ? Icons.remove_red_eye_outlined
              : Icons.screen_rotation_alt_outlined,
          label: _vm.reto == Reto.parpadeo
              ? 'Gesto: parpadear'
              : 'Gesto: girar la cabeza',
        ),
        _buildTelemetryPill(
          icon: _isValidated ? Icons.verified : Icons.timelapse,
          label: _isValidated
              ? 'Identidad confirmada'
              : _vm.paso == PasoVerificacion.comparando
              ? 'Comparando con tu rostro'
              : 'Prueba de vida: ${(_vm.progreso * 100).round()}%',
        ),
      ],
    );
  }

  /// Lo que ve la cámara o, si no se puede abrir, una silueta (el motivo
  /// va en la instrucción, en letra grande).
  Widget _buildVistaDeLaCamara() {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) {
      return Center(
        child: Icon(
          _errorDeCamara == null ? Icons.person : Icons.no_photography_outlined,
          size: _errorDeCamara == null ? 150 : 72,
          color: _primaryLight.withValues(
            alpha: _errorDeCamara == null ? 0.12 : 0.4,
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

  Widget _buildTelemetryPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceControl.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _tertiaryGreen, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
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
          Container(
            padding: const EdgeInsets.all(14),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        color: AppTheme.primaryTexto,
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
                          Text(
                            widget.professorName,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      widget.curso != null
                          ? Icons.info_outline
                          : Icons.lock_outline,
                      color: _systemAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.curso != null
                            ? 'Sin verificar tu rostro no se envía la señal '
                                  'de asistencia.'
                            : 'Tu rostro se compara en este celular: no sale '
                                  'ninguna foto.',
                        style: const TextStyle(
                          color: _systemAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 50,
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: _surfaceControl.withValues(alpha: 0.9),
                foregroundColor: AppTheme.errorTexto,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Cancelar'),
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
          bottomLeft: !isTop && isLeft
              ? const Radius.circular(12)
              : Radius.zero,
          bottomRight: !isTop && !isLeft
              ? const Radius.circular(12)
              : Radius.zero,
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

/// Comprueba que quien tiene el celular es el dueño de la cuenta: prueba de
/// vida y comparación de su cara. Lo usan el marcaje de asistencia (con el
/// [curso] del llamado) y la vinculación del celular (sin curso).
///
/// La primera vez en este celular le pide su consentimiento y lo compara con
/// su foto de Chairá. Devuelve null si cancela o no pasa.
Future<VerificacionFacial?> verificarRostro(
  BuildContext context, {
  Curso? curso,
}) async {
  final uid = context.read<AuthViewModel>().perfil?.uid;
  if (uid == null) return null;
  if (!await IdentidadEnCelular.tieneReferencia(uid)) {
    if (!context.mounted || !await _aceptaRegistrarRostro(context)) {
      return null;
    }
  }
  if (!context.mounted) return null;
  return Navigator.push<VerificacionFacial>(
    context,
    MaterialPageRoute(builder: (_) => FaceVerificationScreen(curso: curso)),
  );
}

/// Lo que salió de comprobar la cara antes de crear una cuenta de estudiante.
enum RostroAlRegistrarse {
  /// Coincidió con la foto de Chairá: el vector queda para guardarlo como
  /// referencia en cuanto exista la cuenta.
  confirmado,

  /// Chairá no tiene foto, o en ella no se ve una cara: no hay con qué
  /// comparar. La cuenta se puede crear, pero sin referencia.
  sinFotoEnChaira,

  /// No aceptó, se salió o su cara no coincidió.
  noConfirmado,
}

/// Antes de crear una cuenta (de estudiante o de docente), comprueba que quien la crea es
/// el dueño del documento: prueba de vida y su cara contra [fotoChaira], la
/// del carné que bajó el paso 1. Sin esto, cualquiera con la cédula de un
/// compañero podría crearle la cuenta y enrolar su propia cara.
Future<({RostroAlRegistrarse estado, List<double>? vector})>
    verificarRostroAlRegistrarse(
  BuildContext context,
  Uint8List? fotoChaira,
) async {
  const sinFoto = (estado: RostroAlRegistrarse.sinFotoEnChaira, vector: null);
  const noConfirmado = (estado: RostroAlRegistrarse.noConfirmado, vector: null);
  if (fotoChaira == null || fotoChaira.isEmpty) return sinFoto;

  final identidad = IdentidadParaRegistro(fotoChaira: fotoChaira);
  try {
    // Antes de abrir la cámara: si en la foto del carné no se ve una cara,
    // pedirle el gesto sería hacerle perder el tiempo.
    if (await identidad.embeddingDeChaira() == null) {
      await identidad.cerrar();
      return sinFoto;
    }
  } catch (_) {
    // Sin modelo no se puede comparar: es lo mismo que no tener con qué.
    await identidad.cerrar();
    return sinFoto;
  }

  if (!context.mounted || !await _aceptaRegistrarRostro(context)) {
    await identidad.cerrar();
    return noConfirmado;
  }
  if (!context.mounted) {
    await identidad.cerrar();
    return noConfirmado;
  }
  // La pantalla cierra el modelo al salir; el vector ya quedó copiado.
  final verificado = await Navigator.push<VerificacionFacial>(
    context,
    MaterialPageRoute(
      builder: (_) => FaceVerificationScreen(identidad: identidad),
    ),
  );
  final vector = identidad.vector;
  if (verificado == null || vector == null) return noConfirmado;
  return (estado: RostroAlRegistrarse.confirmado, vector: vector);
}

/// La primera vez que verifica su cara en este celular: qué se hace con ella
/// y su consentimiento (los datos biométricos son sensibles, Ley 1581 de
/// 2012).
Future<bool> _aceptaRegistrarRostro(BuildContext context) async {
  final acepta = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      title: const Text(
        'Registrar tu rostro',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Para que nadie pueda marcar tu asistencia por ti, vamos a '
        'comparar tu cara con tu foto de Chairá.\n\n'
        'Si coinciden, guardaremos una huella numérica de tu rostro, cifrada '
        'y solo en este celular. No se guarda ninguna foto ni sale nada de '
        'tu teléfono. Puedes borrarla cuando quieras desde Ajustes.',
        style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo, false),
          child: const Text('Ahora no'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogo, true),
          child: const Text('Acepto'),
        ),
      ],
    ),
  );
  return acepta ?? false;
}
