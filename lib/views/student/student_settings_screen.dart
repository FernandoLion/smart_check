import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/asistencia_resumen.dart';
import '../../models/sesion_model.dart';
import '../../models/student_subject_model.dart';
import '../../models/verificacion_result_model.dart';
import '../../services/identidad_facial_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/cerrar_sesion.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/face_verification_viewmodel.dart';
import '../../viewmodels/student_viewmodel.dart';
import '../attendance/face_verification_screen.dart';
import '../login_screen.dart';
import 'attendance_detail_screen.dart';
import 'biometric_validation_screen.dart';
import '../../widgets/ajustes_compartidos.dart';
import '../../widgets/botones_accesibles.dart';
import '../../widgets/texto_sin_cortes.dart';

class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen>
    with SingleTickerProviderStateMixin {
  // Colores exactos del HTML de Stitch
  static const Color _surfaceBg = Color(0xFF131315); // surface / background
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _onPrimary = Color(0xFF1800A7);
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemRed = Color(0xFFFF453A);

  bool _isCopied = false;
  bool _isSyncing = false;
  // Las materias llegan de Firestore en vivo; "sincronizar" vuelve a pedir
  // la asistencia de cada una.
  String _lastSyncText = 'En vivo';

  late final AnimationController _syncController;

  /// Si este celular ya guarda la cara del estudiante. null mientras se
  /// consulta.
  bool? _tieneRostro;

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mirarRostro();
  }

  Future<void> _mirarRostro() async {
    final uid = context.read<AuthViewModel>().perfil?.uid;
    var tiene = false;
    try {
      tiene = uid != null && await IdentidadEnCelular.tieneReferencia(uid);
    } catch (_) {
      // Si el almacén cifrado no responde, se ofrece registrarlo: al
      // intentarlo se verá si de verdad hay uno.
    }
    if (mounted) setState(() => _tieneRostro = tiene);
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  /// El celular que esta cuenta tiene vinculado, o un guion si todavia no
  /// hay ninguno. Es el mismo que comprueba el servidor al firmar la
  /// asistencia, no un identificador de adorno.
  String get _idDelDispositivo =>
      context.read<AuthViewModel>().dispositivoVinculado ?? 'sin vincular';

  Future<void> _handleCopyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: _idDelDispositivo));
    if (!mounted) return;
    setState(() => _isCopied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _handleSyncNow() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _lastSyncText = 'Sincronizando...';
    });
    _syncController.repeat();

    try {
      await context.read<StudentViewModel>().refrescar();
    } catch (_) {
      // El error, si lo hay, lo muestra el portal; aquí solo se para el giro.
    }
    if (!mounted) return;

    _syncController.stop();
    _syncController.reset();
    setState(() {
      _isSyncing = false;
      _lastSyncText = 'Recién';
    });
  }

  Future<void> _handleLogout() async {
    await cerrarSesion(context);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final VerificacionResult? chairaData = authVM.usuarioActual;

    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // TOP STICKY BAR ("Configuración" + Shield + User Avatar)
            _buildTopAppBar(context),

            // MAIN SCROLLABLE SETTINGS CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  // 1. Encabezado principal + Badge "Sincronizado"
                  _buildMainHeader(),
                  const SizedBox(height: 16),

                  // 2. Tarjeta de perfil del estudiante
                  _buildStudentProfileCard(chairaData),
                  const SizedBox(height: 24),

                  // 3. Sección "MIS CURSOS"
                  _buildSectionTitle('MIS CURSOS'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.auto_stories_outlined,
                      title: 'Cursos inscritos',
                      trailingWidget: _buildPillBadge(
                        text: _materias(
                          context.watch<StudentViewModel>().subjects.length,
                        ),
                        bgColor: _surfaceControl,
                        textColor: AppTheme.textSecondary,
                      ),
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.calendar_today_outlined,
                      title: 'Historial de asistencia',
                      trailingText: _porcentajeGlobal(
                        context.watch<StudentViewModel>().globalAttendance,
                      ),
                      trailingTextColor: _colorDe(
                        context.watch<StudentViewModel>().globalAttendance,
                      ),
                      trailingTextBold: true,
                      onTap: _verHistorial,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 4. Sección "CELULAR": el que firma la asistencia.
                  _buildSectionTitle('CELULAR'),
                  _buildGroupedCard([
                    // ID de mi dispositivo + Botón Copiar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _buildIconBox(Icons.badge_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Celular vinculado',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _idDelDispositivo == 'sin vincular'
                                            ? 'Todavía no has vinculado uno'
                                            : 'ID: $_idDelDispositivo',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Sin celular vinculado no hay nada que copiar.
                          if (context
                                  .watch<AuthViewModel>()
                                  .dispositivoVinculado !=
                              null)
                            Tocable(
                            onTap: _handleCopyDeviceId,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceControl,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCopied
                                        ? Icons.check
                                        : Icons.content_copy,
                                    color: _primaryLight,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isCopied ? '¡Copiado!' : 'Copiar',
                                    style: const TextStyle(
                                      color: _primaryLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.phonelink_setup,
                      title: 'Vincular o cambiar de celular',
                      subtitle: 'Tu asistencia solo se firma desde el '
                          'celular vinculado',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BiometricValidationScreen(),
                        ),
                      ),
                    ),
                    _buildDivider(),
                    // Solo informa: la señal se enciende y se apaga sola, no
                    // hay nada que configurar. (Antes abría la misma ayuda
                    // que "Cómo marcar asistencia".)
                    _buildNavRow(
                      icon: Icons.podcasts,
                      title: 'Señal de asistencia',
                      subtitle:
                          'Se enciende sola al marcar asistencia y se '
                          'apaga al cerrarse el llamado',
                      trailingText: 'Automática',
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 5. Sección "PERMISOS DE LA APP": leídos del celular.
                  _buildSectionTitle('PERMISOS DE LA APP'),
                  const PermisosDelCelular(),
                  const SizedBox(height: 24),

                  // 6. Sección "DATOS"
                  _buildSectionTitle('DATOS'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.content_copy_outlined,
                      title: 'Copiar mi historial de asistencia',
                      subtitle: 'Todas tus clases en CSV, para pegar en '
                          'Excel o en un correo',
                      onTap: _copiarHistorial,
                    ),
                    _buildDivider(),
                    InkWell(
                      onTap: _handleSyncNow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  RotationTransition(
                                    turns: _syncController,
                                    child: _buildIconBox(Icons.sync),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextoSinCortes(
                                          'Sincronizar ahora',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        TextoSinCortes(
                                          'Vuelve a pedir tu asistencia',
                                          style: TextStyle(
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
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _lastSyncText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.refresh,
                                    color: AppTheme.textTertiary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 7. Sección "CUENTA Y SEGURIDAD"
                  _buildSectionTitle('CUENTA Y SEGURIDAD'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.lock_reset,
                      title: 'Cambiar contraseña',
                      subtitle: 'Te llega un enlace a tu correo institucional',
                      onTap: () => pedirCambioDeContrasena(context),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.face_outlined,
                      title: _tieneRostro == true
                          ? 'Probar mi rostro'
                          : 'Registrar mi rostro',
                      subtitle: _tieneRostro == true
                          ? 'Se compara con el que guarda este celular'
                          : 'Se compara con tu foto de Chairá',
                      onTap: _probarRostro,
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.face_retouching_off,
                      title: 'Borrar mi rostro de este celular',
                      subtitle: 'Se volverá a comparar con tu foto de Chairá',
                      onTap: _borrarRostro,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 8. Sección "AYUDA"
                  _buildSectionTitle('AYUDA'),
                  _buildGroupedCard([
                    _buildNavRow(
                      icon: Icons.help_center_outlined,
                      title: 'Cómo marcar asistencia',
                      onTap: () => mostrarAyuda(context, docente: false),
                    ),
                    _buildDivider(),
                    _buildNavRow(
                      icon: Icons.security_outlined,
                      title: 'Tus datos y privacidad',
                      onTap: () => mostrarPrivacidad(context),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // 11. Pie de pantalla: Botón "Cerrar sesión" + Versión
                  _buildLogoutFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceBg.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Volver',
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: _primaryLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Configuración',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Tus datos y privacidad',
                onPressed: () => mostrarPrivacidad(context),
                icon: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFC7C4D7),
                  size: 22,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: _onPrimary,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextoSinCortes(
                'Configuración',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Cuenta, señal de asistencia y privacidad',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentProfileCard(VerificacionResult? data) {
    final nombre = data?.nombre ?? '—';
    // El correo real de la cuenta; deducirlo del nombre puede no coincidir.
    final email = context.read<AuthViewModel>().perfil?.email ?? '';
    // Lo que de verdad dice Chairá: el documento y el programa.
    final idInfo = [
      if (data?.cedula != null) 'Doc. ${data!.cedula}',
      if ((data?.programa ?? '').isNotEmpty) data!.programa!,
    ].join(' • ');
    final fotoBytes = data?.imagenBytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surfaceControl, width: 2),
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
                            size: 30,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _tertiaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surfaceElevated, width: 2),
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
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryLight.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                color: _primaryLight,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Estudiante',
                                style: TextStyle(
                                  color: _primaryLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          idInfo,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Estos datos no se editan aquí: son los de Chairá.
          const Text(
            'Tus datos vienen de Chairá. Si algo está mal, corrígelo allá.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildIconBox(IconData icon, {Color iconColor = _primaryLight}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildPillBadge({
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// El historial es por materia: con una sola se abre directo, con varias
  /// se pregunta cuál.
  Future<void> _verHistorial() async {
    final materias = context.read<StudentViewModel>().subjects;
    if (materias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavía no estás inscrito en ninguna materia.'),
        ),
      );
      return;
    }
    final elegida = materias.length == 1
        ? materias.single
        : await showModalBottomSheet<StudentSubjectModel>(
            context: context,
            backgroundColor: _surfaceElevated,
            builder: (hoja) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '¿De qué materia?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final m in materias)
                    ListTile(
                      title: Text(
                        m.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${m.code} • Grupo ${m.group}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      trailing: Text(
                        _porcentajeGlobal(m.attendancePercent)
                            .replaceAll(' global', ''),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () => Navigator.pop(hoja, m),
                    ),
                ],
              ),
            ),
          );
    if (elegida == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceDetailScreen(subject: elegida),
      ),
    );
  }

  /// Todas las clases cerradas de todas sus materias, en CSV y al
  /// portapapeles: sin dependencias de archivos, y se pega igual en Excel
  /// que en un correo.
  Future<void> _copiarHistorial() async {
    final vm = context.read<StudentViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    void avisar(String texto) =>
        messenger.showSnackBar(SnackBar(content: Text(texto)));

    final materias = vm.subjects;
    if (materias.isEmpty) {
      avisar('Todavía no estás inscrito en ninguna materia.');
      return;
    }
    final filas = <String>[
      'Materia;Código;Grupo;Fecha;Estado;Cómo se marcó;Hora',
    ];
    try {
      for (final m in materias) {
        for (final clase in await vm.historialDe(m.cursoId)) {
          final marca = clase.marca;
          final estado = marca == null
              ? 'Faltó'
              : switch (marca.estado) {
                  EstadoAsistencia.tarde => 'Tarde',
                  EstadoAsistencia.ausente => 'Faltó',
                  _ => 'Asistió',
                };
          final como = marca == null
              ? ''
              : marca.metodo == MetodoAsistencia.ble
                  ? 'Bluetooth'
                  : 'A mano';
          filas.add(
            [
              m.name,
              m.code,
              m.group,
              _fechaCsv(clase.franja),
              estado,
              como,
              marca == null ? '' : _horaCsv(marca.hora),
            ].map(_celdaCsv).join(';'),
          );
        }
      }
    } catch (_) {
      avisar('No se pudo leer tu historial. Revisa la conexión.');
      return;
    }
    final clases = filas.length - 1;
    if (clases == 0) {
      avisar('Todavía no hay clases cerradas en tus materias.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: filas.join('\n')));
    avisar(
      clases == 1
          ? 'Copiada 1 clase. Pégala en Excel o en un correo.'
          : 'Copiadas $clases clases. Pégalas en Excel o en un correo.',
    );
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
  static String _fechaCsv(DateTime d) =>
      '${d.year}-${_dos(d.month)}-${_dos(d.day)}';
  static String _horaCsv(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';

  /// Entre comillas si trae el separador, comillas o saltos de línea.
  static String _celdaCsv(String v) =>
      v.contains(RegExp('[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  /// Verde si cumple el mínimo, ámbar si apenas, rojo si no.
  static Color _colorDe(int? porcentaje) {
    if (porcentaje == null) return AppTheme.textSecondary;
    if (porcentaje >= 90) return _tertiaryGreen;
    if (porcentaje >= AsistenciaResumen.minimo) return const Color(0xFFFF9F0A);
    return AppTheme.error;
  }

  static String _materias(int n) => n == 1 ? '1 asignatura' : '$n asignaturas';

  /// La asistencia de todas sus materias, o un guion si aún no hay clases.
  static String _porcentajeGlobal(int? porcentaje) =>
      porcentaje == null ? '—' : '$porcentaje% global';

  /// Registra la cara del estudiante en este celular, o comprueba la que ya
  /// tiene, sin esperar a un llamado: así llega a clase enrolado y no gasta
  /// la ventana de diez minutos en eso.
  Future<void> _probarRostro() async {
    final messenger = ScaffoldMessenger.of(context);
    final rostro = await verificarRostro(context);
    if (!mounted) return;
    await _mirarRostro();
    if (rostro == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          rostro.resultado == ResultadoIdentidad.enrolado
              ? 'Listo: tu rostro quedó registrado en este celular.'
              : 'Listo: eres tú.',
        ),
      ),
    );
  }

  /// Borra la huella numérica del rostro guardada en este celular. La
  /// próxima vez que marque asistencia se volverá a registrar contra Chairá.
  Future<void> _borrarRostro() async {
    final uid = context.read<AuthViewModel>().perfil?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!await IdentidadEnCelular.tieneReferencia(uid)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay un rostro tuyo en este celular.')),
      );
      return;
    }
    if (!mounted) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text(
          '¿Borrar tu rostro?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'La próxima vez que marques asistencia tendrás que registrarlo de '
          'nuevo, comparándolo con tu foto de Chairá.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogo, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirma != true) return;
    await IdentidadEnCelular.olvidar(uid);
    await _mirarRostro();
    messenger.showSnackBar(
      const SnackBar(content: Text('Tu rostro se borró de este celular.')),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Color trailingTextColor = AppTheme.textSecondary,
    bool trailingTextBold = false,
    Widget? trailingWidget,
    // Sin [onTap] la fila solo informa: no responde al toque ni lleva la
    // flecha, para no prometer una pantalla que no hay.
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        // El lado derecho ocupa lo que necesita, hasta el 45% del ancho; el
        // resto es para el título.
        child: LayoutBuilder(
          builder: (context, caja) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildIconBox(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextoSinCortes(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: caja.maxWidth * 0.45),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trailingWidget != null) Flexible(child: trailingWidget),
                    if (trailingText != null)
                      Flexible(
                        child: Text(
                          trailingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: trailingTextColor,
                            fontSize: 13,
                            fontWeight: trailingTextBold
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textTertiary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutFooter() {
    return Column(
      children: [
        GestureDetector(
          onTap: _handleLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _surfaceElevated,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: _systemRed, size: 22),
                SizedBox(width: 8),
                Text(
                  'Cerrar sesión',
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
        const SizedBox(height: 12),
        const Text(
          'Versión 1.0.0 • SmartCheck UDLA Estudiantes',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
      ],
    );
  }
}
