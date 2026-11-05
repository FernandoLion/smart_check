import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/curso_model.dart';
import '../../models/inscrito_model.dart';
import '../../services/ubicacion_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/hoja_geocerca.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/teacher_viewmodel.dart';
import 'add_student_screen.dart';
import 'import_csv_screen.dart';

/// Crea un curso, o edita [curso] si llega uno: mismo formulario, con sus
/// datos cargados. Al editar, devuelve con `Navigator.pop` el curso como
/// quedó guardado.
class CreateCourseScreen extends StatefulWidget {
  final Curso? curso;

  const CreateCourseScreen({super.key, this.curso});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  // Colores exactos extraídos del HTML de Stitch
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _secondaryBlue = Color(0xFF3E90FF);
  static const Color _secondaryLight = Color(0xFFAAC7FF);

  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _groupController = TextEditingController();
  final _classroomController = TextEditingController();
  final List<Horario> _horarios = [];
  final List<Inscrito> _pendientes = [];
  final _ubicacion = UbicacionService();

  /// Dónde está el aula. Sin ella el radar no comprueba el sitio.
  Geocerca? _geocerca;
  bool _marcandoAula = false;

  static const _dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  /// El periodo del curso que se edita, o el de ahora si es nuevo.
  String get _periodo => widget.curso?.periodo ?? Curso.periodoActual();

  bool get _editando => widget.curso != null;

  @override
  void initState() {
    super.initState();
    final curso = widget.curso;
    if (curso != null) {
      _courseNameController.text = curso.nombre;
      _courseCodeController.text = curso.codigo;
      _groupController.text = curso.grupo;
      _classroomController.text = curso.aula;
      _horarios.addAll(curso.horarios);
      _geocerca = curso.geocerca;
    }
  }

  String get _resumenHorario {
    if (_horarios.isEmpty) return 'Toca para agregar';
    return _horarios
        .map((h) => '${_dias[h.dia]} ${h.inicio}-${h.fin}')
        .join(' • ');
  }

  String get _horasSemana {
    final minutos = _horarios.fold<int>(
      0,
      (total, h) => total + h.finMinutos - h.inicioMinutos,
    );
    final horas = minutos / 60;
    final texto = horas == horas.roundToDouble()
        ? horas.toInt().toString()
        : horas.toStringAsFixed(1);
    return '$texto hrs/sem';
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _groupController.dispose();
    _classroomController.dispose();
    super.dispose();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.error),
    );
  }

  Future<void> _handleSaveCourse() async {
    final teacherVM = context.read<TeacherViewModel>();
    if (teacherVM.guardando) return;
    final nombre = _courseNameController.text.trim();
    final codigo = _courseCodeController.text.trim().toUpperCase();
    if (nombre.isEmpty) return _mostrarError('Ingresa el nombre de la materia');
    if (codigo.isEmpty) return _mostrarError('Ingresa el código de la materia');
    if (_horarios.isEmpty) {
      return _mostrarError('Agrega al menos un bloque de horario');
    }
    final perfil = context.read<AuthViewModel>().perfil;
    if (perfil == null) {
      return _mostrarError('Tu sesión expiró. Vuelve a entrar.');
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final original = widget.curso;
    if (original != null) {
      final editado = Curso.fromMap(original.id, {
        ...original.toMap(),
        'codigo': codigo,
        'nombre': nombre,
        'grupo': _groupController.text.trim(),
        'aula': _classroomController.text.trim(),
        'horarios': _horarios.map((h) => h.toMap()).toList(),
        'geocerca': _geocerca?.toMap(),
      });
      final guardado = await teacherVM.editarCurso(editado, _pendientes);
      if (!mounted) return;
      if (!guardado) {
        _mostrarError(teacherVM.error ?? 'No se pudo guardar el curso.');
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Curso "$nombre" actualizado'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
      navigator.pop(editado);
      return;
    }

    final curso = Curso(
      codigo: codigo,
      nombre: nombre,
      grupo: _groupController.text.trim(),
      aula: _classroomController.text.trim(),
      periodo: _periodo,
      docenteUid: perfil.uid,
      docenteNombre: perfil.nombre,
      horarios: List.of(_horarios),
      geocerca: _geocerca,
    );
    final id = await teacherVM.crearCurso(curso, _pendientes);
    if (!mounted) return;
    if (id == null) {
      _mostrarError(teacherVM.error ?? 'No se pudo crear el curso.');
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Curso "$nombre" creado'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
    navigator.pop();
  }

  /// Agrega estudiantes sin repetir (por cédula o correo).
  void _agregarPendientes(List<Inscrito> nuevos) {
    final claves = _pendientes.expand((p) => p.claves).toSet();
    setState(() {
      for (final n in nuevos) {
        if (n.claves.any(claves.contains)) continue;
        claves.addAll(n.claves);
        _pendientes.add(n);
      }
    });
  }

  Future<void> _editarHorario() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _EditorHorario(horarios: _horarios, alCambiar: () => setState(() {})),
    );
  }

  Future<void> _onImportCsvTap() async {
    final nuevos = await Navigator.push<List<Inscrito>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImportCsvScreen(courseName: _courseNameController.text.trim()),
      ),
    );
    if (nuevos != null) _agregarPendientes(nuevos);
  }

  Future<void> _onAddStudentTap() async {
    final nuevos = await Navigator.push<List<Inscrito>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddStudentScreen(courseTitle: _courseNameController.text.trim()),
      ),
    );
    if (nuevos != null) _agregarPendientes(nuevos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUPERTINO MODAL NAVIGATION BAR (Cancelar | Crear Curso | Guardar)
            _buildTopNavigationBar(context),

            // 2. MAIN SCROLLABLE CONTENT CANVAS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                children: [
                  // Banner de Contexto Institucional
                  _buildContextBanner(),
                  const SizedBox(height: 24),

                  // Sección: DATOS GENERALES
                  _buildGeneralDataSection(),
                  const SizedBox(height: 24),

                  // Sección: ESTUDIANTES (Importar CSV + Añadir Cédula)
                  _buildStudentsActionSection(),
                  const SizedBox(height: 20),

                  // Subsección: VISTA PREVIA DE ALUMNOS (3 DE 24 CARGADOS)
                  _buildStudentsPreviewList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavigationBar(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceOled.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // El título se encoge antes que los botones de los lados.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _editando ? 'Editar Curso' : 'Crear Curso',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleSaveCourse,
            child: context.watch<TeacherViewModel>().guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Guardar',
                    style: TextStyle(
                      color: _primaryIndigo,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  color: _primaryIndigo,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'Universidad de la Amazonia • '),
                        TextSpan(
                          text: _periodo,
                          style: const TextStyle(
                            color: Colors.white,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: _tertiaryGreen),
                SizedBox(width: 6),
                Text(
                  'Docente\nTitular',
                  style: TextStyle(
                    color: _tertiaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DATOS GENERALES',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Fila 1: Nombre de la Materia + Código SIS-402
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _primaryIndigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.auto_stories_outlined,
                        color: _primaryIndigo,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre de la Materia',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TextField(
                            controller: _courseNameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Ej. Ingeniería de Software II',
                              hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _courseCodeController,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'CÓDIGO',
                            hintStyle: TextStyle(color: AppTheme.textTertiary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),

              // Fila 2: Horario Semanal
              InkWell(
                onTap: _editarHorario,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _systemAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          color: _systemAmber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Horario Semanal',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _resumenHorario,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _horasSemana,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textTertiary,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildDivider(),

              // Fila: Grupo
              _buildCampoTexto(
                icono: Icons.groups_outlined,
                color: _tertiaryGreen,
                titulo: 'Grupo',
                controller: _groupController,
                pista: 'Ej. 302-B',
              ),
              _buildDivider(),

              // Fila 3: Aula / Ubicación Física + Badge Geocerca ±25m
              InkWell(
                onTap: null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _secondaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.place_outlined,
                          color: _secondaryLight,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aula / Ubicación Física',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TextField(
                              controller: _classroomController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: 'Ej. Bloque B2 - Aula 301',
                                hintStyle: TextStyle(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildInsigniaGeocerca(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _geocerca == null
                ? 'Sin geocerca, el radar no comprobará que la clase se dicte '
                      'en el aula. Párate en el aula y toca la insignia.'
                : 'El radar solo abrirá la clase a menos de '
                      '${_geocerca!.radioMetros.round()} m de este punto.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsigniaGeocerca() {
    final puesta = _geocerca != null;
    final color = puesta ? _tertiaryGreen : _primaryLight;
    return GestureDetector(
      onTap: _marcandoAula ? null : _abrirHojaGeocerca,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (puesta ? _tertiaryContainer : _primaryIndigo).withValues(
            alpha: 0.2,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_marcandoAula)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(
                puesta ? Icons.my_location : Icons.radar,
                color: color,
                size: 13,
              ),
            const SizedBox(width: 5),
            Text(
              puesta
                  ? 'Geocerca\n±${_geocerca!.radioMetros.round()}m'
                  : 'Sin\ngeocerca',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirHojaGeocerca() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HojaGeocerca(
        geocerca: _geocerca,
        alMarcar: _marcarAula,
        alQuitar: () => setState(() => _geocerca = null),
      ),
    );
  }

  /// Toma la ubicación de ahora como centro del aula.
  Future<void> _marcarAula(double radio) async {
    setState(() => _marcandoAula = true);
    try {
      final posicion = await _ubicacion.posicionActual();
      if (!mounted) return;
      setState(() {
        _geocerca = Geocerca(
          latitud: posicion.latitude,
          longitud: posicion.longitude,
          radioMetros: radio,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aula marcada aquí, con GPS ±${posicion.accuracy.round()} m.',
          ),
        ),
      );
    } on UbicacionException catch (e) {
      if (mounted) _mostrarError(e.mensaje);
    } finally {
      if (mounted) setState(() => _marcandoAula = false);
    }
  }

  Widget _buildStudentsActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ESTUDIANTES',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${_pendientes.length} por inscribir',
                style: const TextStyle(
                  color: _tertiaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Tarjeta 1: Importar CSV (Oficial Chairá)
        GestureDetector(
          onTap: _onImportCsvTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _tertiaryContainer.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _tertiaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.table_chart_outlined,
                        color: _tertiaryGreen,
                        size: 20,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _tertiaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _tertiaryGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'Oficial Chairá',
                        style: TextStyle(
                          color: _tertiaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Importar lista',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: AppTheme.textTertiary,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'El Excel de Chairá (.xls o .xlsx), un CSV o pegada',
                  style: TextStyle(color: _tertiaryGreen, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta 2: Añadir Cédula (Manual)
        GestureDetector(
          onTap: _onAddStudentTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dialpad,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Text(
                        'Manual',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Añadir por Cédula o Correo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.add, color: AppTheme.textTertiary, size: 20),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Búsqueda individual en Chairá',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsPreviewList() {
    if (_pendientes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Todavía no hay estudiantes. Puedes crear el curso sin ellos y '
          'agregarlos después.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }
    final visibles = _pendientes.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'VISTA PREVIA (${visibles.length} DE ${_pendientes.length})',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final inscrito in visibles) ...[
                _buildPreviewStudentTile(_PreviewStudent.desde(inscrito)),
                _buildDivider(),
              ],
              InkWell(
                onTap: _verTodos,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _pendientes.length == 1
                            ? 'Ver el estudiante'
                            : 'Ver los ${_pendientes.length} estudiantes',
                        style: const TextStyle(
                          color: _primaryLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: _primaryLight,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _verTodos() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceElevated,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final inscrito in List.of(_pendientes))
                  ListTile(
                    title: Text(
                      inscrito.nombre,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      inscrito.claves.join(' • '),
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                      ),
                      tooltip: 'Quitar',
                      onPressed: () {
                        setState(() => _pendientes.remove(inscrito));
                        setSheet(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampoTexto({
    required IconData icono,
    required Color color,
    required String titulo,
    required TextEditingController controller,
    required String pista,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: pista,
                    hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStudentTile(_PreviewStudent student) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _tertiaryGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        student.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: _tertiaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: _surfaceElevated, width: 2),
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
                        student.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.subtitle,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _tertiaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _tertiaryGreen.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Listo',
              style: TextStyle(
                color: _tertiaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _PreviewStudent {
  final String name;
  final String subtitle;
  final String initials;

  const _PreviewStudent({
    required this.name,
    required this.subtitle,
    required this.initials,
  });

  factory _PreviewStudent.desde(Inscrito inscrito) {
    final partes = inscrito.nombre.trim().split(RegExp(r'\s+'));
    final iniciales = partes.length >= 2
        ? '${partes[0][0]}${partes[1][0]}'
        : inscrito.nombre.padRight(2).substring(0, 2);
    return _PreviewStudent(
      name: inscrito.nombre,
      subtitle: inscrito.claves.join(' • '),
      initials: iniciales.toUpperCase(),
    );
  }
}

/// Hoja para agregar y quitar bloques del horario semanal.
class _EditorHorario extends StatefulWidget {
  final List<Horario> horarios;
  final VoidCallback alCambiar;

  const _EditorHorario({required this.horarios, required this.alCambiar});

  @override
  State<_EditorHorario> createState() => _EditorHorarioState();
}

class _EditorHorarioState extends State<_EditorHorario> {
  static const _dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  int _dia = DateTime.monday;
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 10, minute: 0);

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegir(bool esInicio) async {
    final elegido = await showTimePicker(
      context: context,
      initialTime: esInicio ? _inicio : _fin,
    );
    if (elegido == null) return;
    setState(() {
      if (esInicio) {
        _inicio = elegido;
      } else {
        _fin = elegido;
      }
    });
  }

  void _agregar() {
    final inicio = _inicio.hour * 60 + _inicio.minute;
    final fin = _fin.hour * 60 + _fin.minute;
    if (fin <= inicio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora de fin debe ser después del inicio'),
        ),
      );
      return;
    }
    widget.horarios
      ..add(Horario(dia: _dia, inicio: _hhmm(_inicio), fin: _hhmm(_fin)))
      ..sort(
        (a, b) => a.dia != b.dia
            ? a.dia.compareTo(b.dia)
            : a.inicioMinutos.compareTo(b.inicioMinutos),
      );
    widget.alCambiar();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Horario semanal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final h in List.of(widget.horarios))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${_dias[h.dia]}  ${h.inicio} - ${h.fin}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  tooltip: 'Quitar bloque',
                  onPressed: () {
                    widget.horarios.remove(h);
                    widget.alCambiar();
                    setState(() {});
                  },
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var d = DateTime.monday; d <= DateTime.saturday; d++)
                  ChoiceChip(
                    label: Text(_dias[d]),
                    selected: _dia == d,
                    onSelected: (_) => setState(() => _dia = d),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegir(true),
                    child: Text('Inicio ${_hhmm(_inicio)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegir(false),
                    child: Text('Fin ${_hhmm(_fin)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.add),
                label: const Text('Agregar bloque'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
