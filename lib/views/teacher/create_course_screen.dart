import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'add_student_screen.dart';
import 'import_csv_screen.dart';
class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

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

  late final TextEditingController _courseNameController;
  String _courseCode = 'SIS-402';
  String _schedule = 'Mar / Jue • 08:00 - 10:00 AM';
  String _classroom = 'Bloque B2 - Aula 301';

  final List<_PreviewStudent> _previewStudents = const [
    _PreviewStudent(
      name: 'Diego Fernando Parra',
      subtitle: 'ID: 2021-9923 • Ing. Sistemas',
      initials: 'DP',
    ),
    _PreviewStudent(
      name: 'Valentina Rios Morales',
      subtitle: 'ID: 2021-0492 • Ing. Sistemas',
      initials: 'VR',
    ),
    _PreviewStudent(
      name: 'Mateo Gómez Silva',
      subtitle: 'ID: 2020-8812 • Ing. Software',
      initials: 'MG',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _courseNameController = TextEditingController(
      text: 'Ingeniería de Software II',
    );
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    super.dispose();
  }

  void _handleSaveCourse() {
    if (_courseNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el nombre de la materia'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Según el Roadmap: 10 (Crear Curso) -> Curso creado OK -> 14 (Detalle Curso · Estudiantes)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Curso "${_courseNameController.text.trim()}" guardado con éxito',
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.pop(context);
  }

  void _onImportCsvTap() {
    // Según el Roadmap: Conectará con Pantalla 13 (import_csv_screen.dart)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportCsvScreen(),
      ),
    );
  }

  void _onAddStudentTap() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AddStudentScreen(),
    ),
  );
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
          const Text(
            'Crear Curso',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          GestureDetector(
            onTap: _handleSaveCourse,
            child: const Text(
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
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(text: 'Universidad de la Amazonia • '),
                        TextSpan(
                          text: '2025-1',
                          style: TextStyle(
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
                      child: Text(
                        _courseCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),

              // Fila 2: Horario Semanal
              InkWell(
                onTap: () {},
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
                              _schedule,
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
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '4 hrs/sem',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
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

              // Fila 3: Aula / Ubicación Física + Badge Geocerca ±25m
              InkWell(
                onTap: () {},
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
                            Text(
                              _classroom,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryIndigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _primaryIndigo.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar, color: _primaryLight, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'Geocerca\n±25m',
                              style: TextStyle(
                                color: _primaryLight,
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'La geocerca y la baliza BLE se asociarán automáticamente al aula seleccionada.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.cloud_done_outlined,
                    color: _tertiaryGreen,
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Sincronizado UDLA',
                    style: TextStyle(
                      color: _tertiaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                      'Importar CSV',
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
                  '24 alumnos detectados en archivo',
                  style: TextStyle(
                    color: _tertiaryGreen,
                    fontSize: 13,
                  ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Añadir Cédula',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.add,
                      color: AppTheme.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Búsqueda individual de carné',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsPreviewList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'VISTA PREVIA DE ALUMNOS (3 DE 24 CARGADOS)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'CSV Validado',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
              for (int i = 0; i < _previewStudents.length; i++) ...[
                _buildPreviewStudentTile(_previewStudents[i]),
                _buildDivider(),
              ],
              // Botón inferior dentro de la tarjeta: "Ver los 24 estudiantes importados >"
              InkWell(
                onTap: _onAddStudentTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ver los 24 estudiantes importados',
                        style: TextStyle(
                          color: _primaryLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
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
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
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
}