import 'package:flutter/material.dart';

import '../../models/asistencia_resumen.dart';
import '../../models/curso_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/course_detail_viewmodel.dart';
import '../attendance/attendance_radar_screen.dart';
import 'session_detail_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Curso curso;

  const CourseDetailScreen({super.key, required this.curso});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _diasLargos = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  late final TabController _tabController;
  late final CourseDetailViewModel _vm;
  final _buscador = TextEditingController();

  // Colores exactos del HTML de Stitch
  static const Color _surfaceOled = Color(0xFF0E0E10);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _secondaryBlue = Color(0xFF3E90FF); // secondary-container

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _vm = CourseDetailViewModel()..vigilar(widget.curso.id);
    _buscador.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscador.dispose();
    _vm.dispose();
    super.dispose();
  }

  String _horaDe(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// "Martes 18 de marzo de 2026".
  String _fechaLarga(DateTime d) =>
      '${_diasLargos[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]} '
      'de ${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
          children: [
            // 1. HEADER UNIFICADO (Dynamic Island + Navigation + TabBar)
            _buildHeader(context),

            // 2. CONTENIDO DE LAS PESTAÑAS (Sesiones vs Estudiantes)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // PESTAÑA 1: SESIONES (Pantalla 14)
                  _buildSessionsTab(),

                  // PESTAÑA 2: ESTUDIANTES (Pantalla 15)
                  _buildStudentsTab(),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: _surfaceOled.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          // Dynamic Island Capsule
          Container(
            height: 28,
            width: 176,
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _primaryIndigo,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'BLE Activo',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.sensors, color: _primaryLight, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'SmartCheck',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Navigation Bar (Back, Title & Actions)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios, color: _primaryLight, size: 18),
                    Text(
                      'Mis Clases',
                      style: TextStyle(color: _primaryLight, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.curso.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${widget.curso.codigo} • Grupo '
                      '${widget.curso.grupo}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildActionCircle(Icons.person_add_outlined),
                  const SizedBox(width: 6),
                  _buildActionCircle(Icons.more_horiz),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cupertino Segmented Control (Sesiones / Estudiantes)
          Container(
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.event_note, size: 16),
                      SizedBox(width: 6),
                      Text('Sesiones'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 6),
                      const Text('Estudiantes'),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryIndigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_vm.totalInscritos}',
                          style: const TextStyle(
                            color: _primaryLight,
                            fontSize: 10,
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
    );
  }

  Widget _buildActionCircle(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _surfaceControl.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: _primaryLight, size: 17),
    );
  }

  // ==========================================
  // PESTAÑA 1: SESIONES (Pantalla 14)
  // ==========================================
  Widget _buildSessionsTab() {
    final pasadas = _vm.sesionesPasadas;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildClaseDeHoy(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SESIONES ANTERIORES',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              pasadas.length == 1
                  ? '(1 registrada)'
                  : '(${pasadas.length} registradas)',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (pasadas.isEmpty)
          _buildAviso(
            'Todavía no has cerrado ninguna clase de este curso.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < pasadas.length; i++) ...[
                  if (i > 0) _buildDivider(),
                  _buildSessionTile(pasadas[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAviso(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  /// Tarjeta de arriba: la sesión abierta, la clase de hoy, o nada.
  Widget _buildClaseDeHoy() {
    final ahora = DateTime.now();
    final abierta = _vm.sesionAbierta;
    final bloqueHoy = widget.curso.horarios
        .where((h) => h.dia == ahora.weekday)
        .toList()
      ..sort((a, b) => a.inicioMinutos.compareTo(b.inicioMinutos));

    final String titulo;
    final String insignia;
    final String horario;
    if (abierta != null) {
      titulo = 'CLASE EN CURSO';
      insignia = 'Radar abierto';
      horario = '${_horaDe(abierta.inicio)} - ${_horaDe(abierta.fin)} • '
          '${_fechaLarga(abierta.inicio)}';
    } else if (bloqueHoy.isNotEmpty) {
      titulo = 'CLASE DE HOY';
      final minuto = ahora.hour * 60 + ahora.minute;
      final siguiente = bloqueHoy.firstWhere(
        (h) => h.finMinutos > minuto,
        orElse: () => bloqueHoy.last,
      );
      insignia = siguiente.inicioMinutos > minuto ? 'Por empezar' : 'En horario';
      horario = '${siguiente.inicio} - ${siguiente.fin} • '
          '${_diasLargos[ahora.weekday - 1]}';
    } else {
      titulo = 'SIN CLASE HOY';
      insignia = 'En reposo';
      horario = widget.curso.horarios.isEmpty
          ? 'Este curso no tiene horario asignado'
          : 'Días de clase: ${widget.curso.horarios.map((h) => _dias[h.dia - 1]).join(', ')}';
    }

    final geocerca = widget.curso.geocerca;
    final promedio = _vm.promedio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor:
                        abierta != null ? _tertiaryGreen : AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _tertiaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _tertiaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  insignia,
                  style: const TextStyle(
                    color: _tertiaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule, color: _primaryLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  horario,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: _secondaryBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  geocerca == null
                      ? '${widget.curso.aula} • Sin geocerca asignada'
                      : '${widget.curso.aula} • Geocerca ±'
                          '${geocerca.radioMetros.round()}m',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetrica(
                  'Alumnos Inscritos',
                  _vm.totalInscritos == 1
                      ? '1 inscrito'
                      : '${_vm.totalInscritos} inscritos',
                  Icons.person_outline,
                  AppTheme.textTertiary,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetrica(
                  'Asistencia Promedio',
                  promedio.porcentaje == null
                      ? 'Sin clases aún'
                      : '${promedio.porcentaje}% asistencia',
                  Icons.trending_up,
                  _tertiaryGreen,
                  promedio.porcentaje == null ? Colors.white : _tertiaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    const AttendanceRadarScreen();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sensors, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Iniciar Radar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _surfaceControl,
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pin_drop_outlined,
                        color: _secondaryBlue,
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Editar Geocerca',
                        style: TextStyle(
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
        ],
      ),
    );
  }

  Widget _buildMiniMetrica(
    String titulo,
    String valor,
    IconData icono,
    Color colorIcono,
    Color colorValor,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceControl.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                    color: colorValor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(icono, color: colorIcono, size: 20),
        ],
      ),
    );
  }

  Widget _buildSessionTile(SesionResumen resumen) {
    final sesion = resumen.sesion;
    final aviso = resumen.bajaAsistencia;
    final porcentaje = resumen.porcentaje;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(
              courseName: widget.curso.nombre,
              courseCodeAndGroup:
                  '${widget.curso.codigo} • Grupo ${widget.curso.grupo}',
              sessionDateTitle: _fechaLarga(sesion.inicio),
              sessionTimeRange:
                  '${_horaDe(sesion.inicio)} - ${_horaDe(sesion.fin)}',
              presentCount: resumen.asistieron,
              totalCount: resumen.inscritos,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  // Calendario miniatura
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dias[sesion.inicio.weekday - 1],
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${sesion.inicio.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ],
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
                                _fechaLarga(sesion.inicio),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: aviso
                                    ? _systemAmber.withValues(alpha: 0.2)
                                    : _surfaceControl,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: aviso
                                      ? _systemAmber.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                aviso ? 'Baja asistencia' : 'Cerrada',
                                style: TextStyle(
                                  color: aviso
                                      ? _systemAmber
                                      : AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              porcentaje == null
                                  ? 'Sin inscritos'
                                  : '$porcentaje% (${resumen.asistieron}/'
                                      '${resumen.inscritos})',
                              style: TextStyle(
                                color: aviso ? _systemAmber : _tertiaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppTheme.textTertiary),
                            ),
                            Flexible(
                              child: Text(
                                '${_horaDe(sesion.inicio)} - '
                                '${_horaDe(sesion.fin)}',
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
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: ESTUDIANTES (Pantalla 15)
  // ==========================================
  Widget _buildStudentsTab() {
    final busqueda = _buscador.text.trim().toLowerCase();
    final todos = _vm.inscritos;
    final lista = busqueda.isEmpty
        ? todos
        : todos
            .where((i) =>
                i.nombre.toLowerCase().contains(busqueda) ||
                i.identificacion.toLowerCase().contains(busqueda))
            .toList();
    final promedio = _vm.promedio;
    final enRiesgo = _vm.enRiesgo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Buscador
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surfaceControl,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _buscador,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, cédula o correo...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (busqueda.isNotEmpty)
                GestureDetector(
                  onTap: _buscador.clear,
                  child: const Icon(
                    Icons.cancel,
                    color: AppTheme.textTertiary,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Resumen del curso
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: _primaryLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _vm.totalInscritos == 1
                                    ? '1 Inscrito'
                                    : '${_vm.totalInscritos} Inscritos',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const CircleAvatar(
                                radius: 2.5,
                                backgroundColor: AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                enRiesgo == 1
                                    ? '1 en Riesgo'
                                    : '$enRiesgo en Riesgo',
                                style: TextStyle(
                                  color: enRiesgo == 0
                                      ? AppTheme.textSecondary
                                      : _systemRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mínimo institucional: '
                            '${AsistenciaResumen.minimo}% de asistencia',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
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
                  Text(
                    promedio.porcentaje == null
                        ? '—'
                        : '${promedio.porcentaje}%',
                    style: const TextStyle(
                      color: _tertiaryGreen,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Promedio',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'LISTA DE INSCRITOS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (_vm.totalInscritos == 0)
          _buildAviso(
            'Este curso no tiene inscritos. Agrégalos por CSV, cédula o '
            'correo desde el panel docente.',
          )
        else if (lista.isEmpty)
          _buildAviso('Ningún inscrito coincide con la búsqueda.')
        else
          for (final inscrito in lista) ...[
            _buildStudentCard(inscrito),
            const SizedBox(height: 12),
          ],

        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceControl.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El estudiante que baje del '
                  '${AsistenciaResumen.minimo}% de asistencia reprueba la '
                  'asignatura. Solo cuentan las clases ya cerradas.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _faltas(int n) => n == 1 ? '1 falta' : '$n faltas';

  Widget _buildStudentCard(InscritoAsistencia inscrito) {
    final a = inscrito.asistencia;
    final nivel = a.nivel;
    final critico = nivel == NivelAsistencia.riesgo;
    final alerta = nivel == NivelAsistencia.atencion;
    final porcentaje = a.porcentaje;

    final String tituloRiesgo;
    final String subtituloRiesgo;
    if (a.sesiones == 0) {
      tituloRiesgo = 'Sin clases cerradas todavía';
      subtituloRiesgo = 'Nada que contar';
    } else {
      tituloRiesgo = a.faltas == 0
          ? 'Sin inasistencias registradas'
          : '${_faltas(a.faltas)} • máximo ${_faltas(a.faltasPermitidas)}';
      if (critico) {
        subtituloRiesgo = 'Por debajo del mínimo';
      } else if (a.faltasDisponibles == 0) {
        subtituloRiesgo = 'La próxima falta lo reprueba';
      } else {
        subtituloRiesgo = a.faltasDisponibles == 1
            ? 'Le queda 1 falta'
            : 'Le quedan ${a.faltasDisponibles} faltas';
      }
    }

    return _buildStudentRiskCard(
      name: inscrito.nombre,
      id: inscrito.identificacion,
      faultsText: a.sesiones == 0 ? 'Sin clases aún' : _faltas(a.faltas),
      attendanceText:
          porcentaje == null ? 'Sin asistencia' : '$porcentaje% Asist.',
      badgeLabel: critico
          ? 'Riesgo Crítico'
          : alerta
              ? 'Alerta'
              : 'Normal',
      badgeColor: critico
          ? _systemRed
          : alerta
              ? _systemAmber
              : _tertiaryGreen,
      progressFraction: a.faltasPermitidas == 0
          ? 0
          : a.faltas / a.faltasPermitidas,
      riskTitle: tituloRiesgo,
      riskSubtitle: subtituloRiesgo,
      isRiskCritical: critico,
      isWarning: alerta,
    );
  }

  Widget _buildStudentRiskCard({
    required String name,
    required String id,
    required String faultsText,
    required String attendanceText,
    required String badgeLabel,
    required Color badgeColor,
    required double progressFraction,
    required String riskTitle,
    required String riskSubtitle,
    bool isRiskCritical = false,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRiskCritical
              ? _systemRed.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.textSecondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
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
                            id,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                faultsText,
                                style: TextStyle(
                                  color: isRiskCritical
                                      ? _systemRed
                                      : isWarning
                                      ? _systemAmber
                                      : _tertiaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                ' • ',
                                style: TextStyle(color: AppTheme.textTertiary),
                              ),
                              Text(
                                attendanceText,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Termómetro de Riesgo individual
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    riskTitle,
                    style: TextStyle(
                      color: isRiskCritical
                          ? _systemRed
                          : isWarning
                          ? _systemAmber
                          : AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: isRiskCritical
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    riskSubtitle,
                    style: TextStyle(
                      color: isRiskCritical
                          ? _systemRed
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isRiskCritical
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 8,
                width: double.infinity,
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressFraction.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRiskCritical
                          ? _systemRed
                          : isWarning
                          ? _systemAmber
                          : _tertiaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.08));
  }
}
