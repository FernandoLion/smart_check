import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/verificacion_result_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

class CedulaLoginScreen extends StatefulWidget {
  final String courseDestination;

  const CedulaLoginScreen({
    super.key,
    this.courseDestination = 'Ingeniería de Software II • Grupo 302-B',
  });

  @override
  State<CedulaLoginScreen> createState() => _CedulaLoginScreenState();
}

class _CedulaLoginScreenState extends State<CedulaLoginScreen> {
  // Colores exactos del HTML de Stitch (todos declarados para evitar errores)
  static const Color _surfaceBg = Color(0xFF131315); // surface / background
  static const Color _surfaceLowest = Color(0xFF0E0E10);
  static const Color _surfaceLow = Color(0xFF1B1B1D);
  static const Color _surfaceContainer = Color(0xFF1F1F21);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceVariant = Color(0xFF353437);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _onPrimary = Color(0xFF1800A7);
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _onTertiaryContainer = Color(0xFFCDFFCA);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);

  late final TextEditingController _searchController;

  bool _isMatchVisible = true;
  bool _isEnrolling = false;
  bool _isEnrollSuccess = false;
  String? _toastMessage;

  final List<_SessionEnrolledItem> _sessionStudents = [
    const _SessionEnrolledItem(
      id: 'student-item-1',
      name: 'Sofía Mendoza Cruz',
      code: 'ID: 2022-3419',
      statusLabel: 'Inscrita recién',
      isRecent: true,
      initials: 'SM',
    ),
    const _SessionEnrolledItem(
      id: 'student-item-2',
      name: 'Mateo Gómez Silva',
      code: 'ID: 2020-8812',
      statusLabel: 'Inscrito hace 5m',
      isRecent: false,
      initials: 'MG',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: '1117540289');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchTyping(String val) {
    final cleanVal = val.trim();
    setState(() {
      _isMatchVisible = cleanVal == '1117540289' ||
          cleanVal == '2022-3810' ||
          cleanVal.length >= 8;
    });
  }

  void _clearSearchField() {
    _searchController.clear();
    _handleSearchTyping('');
  }

  Future<void> _performLiveChairaLookup() async {
    final doc = _searchController.text.trim();
    if (doc.isEmpty) return;
    await context.read<AuthViewModel>().verificarEnChaira(doc);
    if (!mounted) return;
    setState(() => _isMatchVisible = true);
  }

  Future<void> _enrollCurrentStudent(String studentName, String code) async {
    if (_isEnrolling || !_isMatchVisible) return;

    setState(() => _isEnrolling = true);

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final parts = studentName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : studentName.substring(0, 2).toUpperCase();

    setState(() {
      _isEnrolling = false;
      _isEnrollSuccess = true;
      _toastMessage = '$studentName añadido al Grupo 302-B';
      _sessionStudents.insert(
        0,
        _SessionEnrolledItem(
          id: 'student-item-${DateTime.now().millisecondsSinceEpoch}',
          name: studentName,
          code: 'ID: $code',
          statusLabel: 'Inscrito recién',
          isRecent: true,
          initials: initials,
        ),
      );
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _isEnrollSuccess = false);
    });
  }

  void _undoStudentAddition(int index) {
    final removed = _sessionStudents[index];
    setState(() {
      _sessionStudents.removeAt(index);
      _toastMessage = 'Inscripción de ${removed.name} revocada';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final VerificacionResult? liveResult = authVM.verificacionResult;

    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. TOP STICKY NAVIGATION HEADER (< Volver | Búsqueda Por Cédula | Listo)
            _buildTopHeader(context),

            // 2. MAIN SCROLLABLE CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  // Dynamic Notification Feedback Banner (liveFeedbackToast)
                  if (_toastMessage != null) ...[
                    _buildLiveFeedbackToast(),
                    const SizedBox(height: 12),
                  ],

                  // Academic Context Sub-header Bar
                  _buildAcademicContextCard(),
                  const SizedBox(height: 16),

                  // iOS Cupertino Interactive Search Field + Match Status Chip
                  _buildInteractiveSearchSection(authVM.isVerifyingChaira),
                  const SizedBox(height: 20),

                  // High Priority Student Result Card
                  _buildStudentProfileCard(liveResult),
                  const SizedBox(height: 24),

                  // Added In This Session Section
                  _buildAddedInSessionSection(),
                  const SizedBox(height: 16),

                  // Institutional Compliance & Audit Footnote
                  _buildAuditFootnote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceBg.withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new, color: _primaryLight, size: 20),
                SizedBox(width: 4),
                Text(
                  'Volver',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Text(
              'Búsqueda Por Cédula',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Listo',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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

  Widget _buildLiveFeedbackToast() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tertiaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: _tertiaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _toastMessage!,
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
          GestureDetector(
            onTap: () => setState(() => _toastMessage = null),
            child: const Icon(
              Icons.close,
              color: AppTheme.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: _tertiaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'CHAIRÁ DB EN LÍNEA',
                    style: TextStyle(
                      color: _tertiaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, color: _systemAmber, size: 13),
                    SizedBox(width: 4),
                    Text(
                      '2025-1',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Curso Destino',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.courseDestination,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSearchSection(bool isVerifying) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _surfaceControl,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _performLiveChairaLookup,
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
                  onChanged: _handleSearchTyping,
                  onSubmitted: (_) => _performLiveChairaLookup(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cédula de Ciudadanía o Código Chairá...',
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
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearchField,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: _surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Status feedback chip below input
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isMatchVisible ? 1.0 : 0.3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: _tertiaryGreen),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Coincidencia exacta encontrada en registro UDLA',
                          style: TextStyle(
                            color: _tertiaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Chairá Sync 12ms',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentProfileCard(VerificacionResult? liveResult) {
    final hasLive = liveResult != null && liveResult.success;
    final nombre = hasLive
        ? (liveResult.nombre ?? 'Carlos Andrés Muñoz')
        : 'Carlos Andrés Muñoz';
    final carrera = hasLive
        ? '${liveResult.programa ?? 'Ingeniería de Sistemas'} • Semestre VI'
        : 'Ingeniería de Sistemas • Semestre VI';
    final cedula = hasLive
        ? (liveResult.cedula ?? _searchController.text)
        : '1.117.540.289';
    final codigoInst = '2022-3810';
    final fotoBytes = hasLive ? liveResult.imagenBytes : null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _isMatchVisible ? 1.0 : 0.45,
      child: IgnorePointer(
        ignoring: !_isMatchVisible,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceElevated,
            borderRadius: BorderRadius.circular(24),
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
              // 1. Profile Header Row
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
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: _surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: _tertiaryGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _tertiaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Estudiante Regular Activo',
                            style: TextStyle(
                              color: _tertiaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          carrera,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Compact Technical Metadata Well
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Código Institucional',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            codigoInst,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Documento CC',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          cedula,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sede Académica',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Campus Principal Florencia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Credential & Verification Badges
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _tertiaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.face, color: _tertiaryGreen, size: 17),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Face ID Enrolado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.verified,
                            color: _tertiaryGreen,
                            size: 15,
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
                        color: _primaryIndigo.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.contactless,
                            color: _primaryLight,
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'BLE Pass Activo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.check, color: _primaryLight, size: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Matrícula 2025-1 Validada Callout
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.event_available,
                        color: _tertiaryGreen,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Matrícula 2025-1 Validada',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sin colisión horaria con Grupo 302-B (Mar-Jue 08:00 - 10:00)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Primary Action CTA ("Añadir al Curso 302-B")
              ElevatedButton(
                onPressed: _isEnrolling
                    ? null
                    : () => _enrollCurrentStudent(nombre, codigoInst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEnrollSuccess
                      ? _tertiaryContainer
                      : _primaryIndigo,
                  foregroundColor: _isEnrollSuccess
                      ? _onTertiaryContainer
                      : Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                child: _isEnrolling
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Registrando en Chairá...',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEnrollSuccess ? Icons.check : Icons.person_add,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEnrollSuccess
                                ? '¡Añadido con Éxito!'
                                : 'Añadir al Curso 302-B',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),

              // Secondary Info Link
              GestureDetector(
                onTap: () {},
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ver ficha académica completa en Chairá',
                      style: TextStyle(
                        color: _primaryLight,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: _primaryLight,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddedInSessionSection() {
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
                    'Añadidos en esta sesión',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_sessionStudents.length}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'Sesión activa',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < _sessionStudents.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSessionStudentRow(_sessionStudents[i], i),
          ),
      ],
    );
  }

  Widget _buildSessionStudentRow(_SessionEnrolledItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _primaryIndigo.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: _tertiaryGreen,
                          shape: BoxShape.circle,
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
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.code,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppTheme.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.statusLabel,
                              style: TextStyle(
                                color: item.isRecent
                                    ? _tertiaryGreen
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
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
          GestureDetector(
            onTap: () => _undoStudentAddition(index),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surfaceControl,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.undo,
                color: AppTheme.textSecondary,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditFootnote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.verified_user,
              color: AppTheme.textTertiary,
              size: 18,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sincronizado con base de datos central Chairá UDLA. Registro auditado con firma criptográfica del docente titular. Las modificaciones impactan las listas físicas de control de acceso perimetral.',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionEnrolledItem {
  final String id;
  final String name;
  final String code;
  final String statusLabel;
  final bool isRecent;
  final String initials;

  const _SessionEnrolledItem({
    required this.id,
    required this.name,
    required this.code,
    required this.statusLabel,
    required this.isRecent,
    required this.initials,
  });
}