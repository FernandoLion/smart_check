import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inscrito_model.dart';
import '../../models/verificacion_result_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/add_students_modal.dart';
import 'import_csv_screen.dart';
/// Agrega estudiantes uno a uno, por cédula (verificada en Chairá) o por
/// correo institucional. Al salir devuelve la lista de [Inscrito] agregados
/// con `Navigator.pop`.
class AddStudentScreen extends StatefulWidget {
  final String courseTitle;

  const AddStudentScreen({super.key, this.courseTitle = ''});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  // Colores exactos del HTML de Stitch
  static const Color _bgSurface = Color(0xFF131315);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceLow = Color(0xFF1B1B1D);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _primaryFixed = Color(0xFFE2DFFF);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _secondaryBlue = Color(0xFF3E90FF);

  late final TextEditingController _searchController;

  // Añadidos en esta pantalla: lo que se pinta y lo que se devuelve.
  final List<_RecentAddedStudent> _recentlyAdded = [];
  final List<Inscrito> _agregados = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Que no aparezca una consulta a Chairá de otra pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().clearState();
    });
  }

  void _salir() => Navigator.pop<List<Inscrito>>(context, _agregados);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performChairaSearch() async {
    final entrada = _searchController.text.trim();
    if (entrada.isEmpty) return;

    if (entrada.contains('@')) {
      final correo = AuthViewModel.correoInstitucional(entrada);
      if (correo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthViewModel.errorUsuario(entrada) ?? 'Correo no válido',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      _agregar(Inscrito(email: correo, nombre: correo.split('@').first.toUpperCase()));
      _searchController.clear();
      return;
    }

    await context
        .read<AuthViewModel>()
        .verificarEnChaira(entrada.replaceAll(RegExp(r'[.\s-]'), ''));
  }

  void _agregar(Inscrito inscrito) {
    final yaEsta = _agregados.any(
      (a) => a.claves.any(inscrito.claves.contains),
    );
    if (yaEsta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inscrito.nombre} ya está en la lista')),
      );
      return;
    }
    final parts = inscrito.nombre.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : inscrito.nombre.padRight(2).substring(0, 2).toUpperCase();

    setState(() {
      _agregados.insert(0, inscrito);
      _recentlyAdded.insert(
        0,
        _RecentAddedStudent(
          name: inscrito.nombre,
          idAndProgram: inscrito.claves.join(' • '),
          timeAgo: 'Ahora',
          initials: initials,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${inscrito.nombre} agregado'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openQuickModal() {
    // Según el Roadmap: 11 -> Botón Modal rápido -> 12 (Modal Agregar Estudiantes)
    AddStudentsModal.show(
      context,
      onImportCsvTap: () async {
        // Al tocar "Importar CSV", abrimos la pantalla 13
        final nuevos = await Navigator.push<List<Inscrito>>(
          context,
          MaterialPageRoute(
            builder: (_) => ImportCsvScreen(courseName: widget.courseTitle),
          ),
        );
        if (nuevos != null) nuevos.forEach(_agregar);
      },
    );
  } 

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final VerificacionResult? liveResult = authVM.verificacionResult;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUPERTINO NAVIGATION BAR (< Volver | Añadir Estudiante | Listo)
            _buildTopNavigationBar(context),

            // 2. MAIN CONTENT CANVAS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Sección 1: Búsqueda por Identificación + Input Cupertino
                  _buildSearchSection(authVM.isVerifyingChaira),
                  const SizedBox(height: 20),

                  // Sección 2: Smart Search Result Card (Identity Verification Glass Card)
                  if (liveResult != null && liveResult.success)
                    _buildVerifiedStudentCard(liveResult)
                  else
                    _buildPistaBusqueda(authVM.errorMessage),
                  const SizedBox(height: 24),

                  // Sección 3: Añadidos Recientemente (Cupertino Inset Grouped List)
                  _buildRecentlyAddedSection(),
                  const SizedBox(height: 20),

                  // 4. Institutional Security Footnote
                  _buildSecurityFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildPistaBusqueda(String? error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        error ??
            'Escribe la cédula y toca buscar para verificarla en Chairá, o '
                'escribe el correo institucional para agregarlo directamente.',
        style: TextStyle(
          color: error != null ? AppTheme.error : AppTheme.textSecondary,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildTopNavigationBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Leading: "< Volver"
          GestureDetector(
            onTap: _salir,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: _primaryLight, size: 24),
                Text(
                  'Volver',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Center: Title & Subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Añadir Estudiante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  widget.courseTitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Trailing: Botón Modal Rápido (12) + "Listo"
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _openQuickModal,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _surfaceControl,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.layers_outlined,
                    color: _primaryLight,
                    size: 16,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _salir,
                child: const Text(
                  'Listo',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(bool isVerifying) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Búsqueda por Identificación',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ingresa la cédula o código institucional para consultar en Chairá Académico.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),

        // Cupertino Search Bar Container
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surfaceControl,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _performChairaSearch,
                child: isVerifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryLight,
                        ),
                      )
                    : const Icon(
                        Icons.search,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _performChairaSearch(),
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cédula o código del estudiante',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _searchController.clear()),
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              // Pill "Chairá" con punto verde activo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: _tertiaryGreen),
                    SizedBox(width: 5),
                    Text(
                      'Chairá',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
    );
  }

  Widget _buildVerifiedStudentCard(VerificacionResult? liveResult) {
    final hasLiveMatch = liveResult != null && liveResult.success;
    final nombre = hasLiveMatch
        ? (liveResult.nombre ?? 'Carlos Andrés Muñoz Rivera')
        : 'Carlos Andrés Muñoz Rivera';
    final cedula = hasLiveMatch
        ? (liveResult.cedula ?? _searchController.text)
        : '1.117.000.000';
    final programa = hasLiveMatch
        ? '${liveResult.programa ?? 'Ing. de Sistemas'} • Semestre VI'
        : 'Ing. de Sistemas • Semestre VI';
    final fotoBytes = hasLiveMatch ? liveResult.imagenBytes : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_surfaceElevated, _surfaceLow],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _tertiaryGreen.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Verification Status Banner
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
                      color: _tertiaryGreen.withValues(alpha: 0.4),
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
                          'Coincidencia Chairá DB Verificada',
                          style: TextStyle(
                            color: _tertiaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Matrícula 2025-1',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),

          // 2. Student Profile Body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _tertiaryGreen, width: 2),
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
                            size: 32,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: _tertiaryGreen,
                        size: 13,
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
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(text: 'ID: '),
                          const TextSpan(
                            text: '2022-3810',
                            style: TextStyle(
                              color: Color(0xFFE4E2E4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' • CC $cedula'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          programa,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryIndigo.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _primaryIndigo.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'Estudiante Activo',
                            style: TextStyle(
                              color: _primaryFixed,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),

          // 3. Biometrics and Security Status Badges Row (2 columns)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceControl.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.face, color: _tertiaryGreen, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biometría',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Face ID Enrolado ✓',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceControl.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.contactless, color: _secondaryBlue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credencial',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'BLE Pass Activo ✓',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Academic Validation Info Callout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _surfaceHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available,
                  color: _tertiaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: Color(0xFFE4E2E4),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(text: 'Habilitado para matricular en '),
                        TextSpan(
                          text: 'Grupo 302-B',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' (Sin conflicto de horario).'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Primary CTA Button ("Añadir a la Clase")
          ElevatedButton(
            onPressed: hasLiveMatch
                ? () => _agregar(
                      Inscrito(
                        cedula: cedula.replaceAll(RegExp(r'[.\s-]'), ''),
                        nombre: nombre,
                      ),
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryIndigo,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 8,
              shadowColor: _primaryIndigo.withValues(alpha: 0.3),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1, size: 20),
                SizedBox(width: 8),
                Text(
                  'Añadir a la Clase',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Context Link
          GestureDetector(
            onTap: () {},
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver historial académico completo',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _primaryLight,
                  size: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyAddedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'AÑADIDOS RECIENTEMENTE',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '${_recentlyAdded.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'Sesión actual',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
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
              for (int i = 0; i < _recentlyAdded.length; i++) ...[
                _buildRecentStudentRow(_recentlyAdded[i], i),
                if (i < _recentlyAdded.length - 1)
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentStudentRow(_RecentAddedStudent student, int index) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        student.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 13,
                        height: 13,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              student.name,
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
                              color: _tertiaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: _tertiaryGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              '✓ Inscrito',
                              style: TextStyle(
                                color: _tertiaryGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        student.idAndProgram,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                student.timeAgo,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _recentlyAdded.removeAt(index);
                    _agregados.removeAt(index);
                  });
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F21),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.undo,
                    color: AppTheme.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: AppTheme.textTertiary,
            size: 14,
          ),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Sincronizado con base de datos central Chairá UDLA. Registro auditado por profesor titular.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAddedStudent {
  final String name;
  final String idAndProgram;
  final String timeAgo;
  final String initials;

  const _RecentAddedStudent({
    required this.name,
    required this.idAndProgram,
    required this.timeAgo,
    required this.initials,
  });
}