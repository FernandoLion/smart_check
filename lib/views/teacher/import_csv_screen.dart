import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'dart:async';

class ImportCsvScreen extends StatefulWidget {
  final String courseName;
  final String groupInfo;

  const ImportCsvScreen({
    super.key,
    this.courseName = 'Ingeniería de Software II',
    this.groupInfo = 'Grupo 302-B • Código SIS-402',
  });

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  // Colores exactos del HTML de Stitch
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceBg = Color(0xFF131315);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _surfaceHighest = Color(0xFF353437);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _onPrimary = Color(0xFF1800A7);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _secondaryBlue = Color(0xFFAAC7FF); // secondary (light blue)
  static const Color _systemAmber = Color(0xFFFF9F0A);

  // Estados del botón principal interactivo
  bool _isImporting = false;
  bool _isSuccess = false;

  void _handleImportAction() {
    if (_isImporting || _isSuccess) return;

    setState(() {
      _isImporting = true;
    });

    // Simula la interacción JS de Stitch: "Enrolando 24 Registros..." -> 1100ms -> "¡Sincronización Exitosa!"
    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _isSuccess = true;
      });

      // Navega de regreso simulando la carga exitosa de la data
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        Navigator.pop(context, true); // Devuelve true para indicar éxito a la vista anterior
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. TOP HEADER APP BAR
            _buildTopAppBar(context),

            // 2. MAIN SCROLLABLE CONTENT CANVAS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  const SizedBox(height: 16),

                  // Header Banner Institucional Chairá
                  _buildInstitutionalBanner(),
                  const SizedBox(height: 16),

                  // Tarjeta CSV Status / Carga interactiva
                  _buildCsvFileStatusCard(),
                  const SizedBox(height: 16),

                  // Mapeo Automático de Columnas
                  _buildSmartMappingCard(),
                  const SizedBox(height: 16),

                  // Vista previa de estudiantes detectados
                  _buildIdentifiedRecordsCard(),
                  const SizedBox(height: 16),

                  // Callout Acuerdo Académico 014
                  _buildAcademicRuleCallout(),
                  const SizedBox(height: 16),

                  // Botones de Acción Primaria
                  _buildPrimaryActionButtons(context),
                  const SizedBox(height: 16),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceBg.withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  'Atrás',
                  style: TextStyle(
                    color: _primaryLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Text(
              'Importar Csv Chairá',
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
                onTap: _handleImportAction,
                child: const Text(
                  'Confirmar',
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
                child: const Icon(Icons.person, color: _onPrimary, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Ambient Glow Effect
          Positioned(
            right: -24,
            bottom: -24,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: _tertiaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _tertiaryContainer.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: _tertiaryGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Chairá Académico 2025-1',
                        style: TextStyle(
                          color: _tertiaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _surfaceHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: _secondaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Oficial UDLA',
                          style: TextStyle(
                            color: _secondaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.courseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.school, color: AppTheme.textTertiary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.groupInfo,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCsvFileStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryIndigo.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined, // Fallback si no hay icon 'csv' custom
                  color: _primaryLight,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'nomina_estudiantes_sis402_2025_1.csv',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '42.8 KB • Formato UTF-8 (Delimitado por comas)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _tertiaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: _tertiaryGreen,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Micro-status de validación de sintaxis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceControl,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.rule, color: _tertiaryGreen, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '24 estudiantes detectados sin errores',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  '100% Válido',
                  style: TextStyle(
                    color: _tertiaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Acciones secundarias de archivo
          Row(
            children: [
              Expanded(
                child: _buildSecondaryActionButton(
                  icon: Icons.sync,
                  label: 'Reemplazar',
                  color: _primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSecondaryActionButton(
                  icon: Icons.download,
                  label: 'Plantilla Chairá',
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActionButton({required IconData icon, required String label, required Color color}) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMappingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.dataset, color: _primaryLight, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Mapeo Inteligente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tertiaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '4/4 Enlazados',
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

          // Mapeo Group List
          _buildMappingRow('Documento Identidad', 'COD_ESTUDIANTE', 'Columna A'),
          const SizedBox(height: 6),
          _buildMappingRow('Nombre Completo', 'NOMBRE_COMPLETO', 'Columna B'),
          const SizedBox(height: 6),
          _buildMappingRow('Correo Institucional', 'EMAIL_INSTITUCIONAL', 'Columna C'),
          const SizedBox(height: 6),
          _buildMappingRow('Carrera / Facultad', 'PROGRAMA_ACADEMICO', 'Columna D'),
        ],
      ),
    );
  }

  Widget _buildMappingRow(String title, String fieldName, String column) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceControl,
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
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fieldName,
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
              const Icon(Icons.done_all, color: _tertiaryGreen, size: 16),
              const SizedBox(width: 4),
              Text(
                column,
                style: const TextStyle(
                  color: _tertiaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentifiedRecordsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registros Identificados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '24 de 24 listos para sincronizar',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.filter_list,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de Estudiantes (los 3 del mockup)
          _buildPreviewStudentRow(
            name: 'Mateo Gómez Silva',
            details: 'ID: 2022-1049 • m.gomez@udla.edu.co',
            semester: 'Semestre VI',
          ),
          const SizedBox(height: 6),
          _buildPreviewStudentRow(
            name: 'Diego Fernando Parra',
            details: 'ID: 2021-9923 • d.parra@udla.edu.co',
            semester: 'Semestre VII',
          ),
          const SizedBox(height: 6),
          _buildPreviewStudentRow(
            name: 'Valentina Ríos Morales',
            details: 'ID: 2021-8842 • v.rios@udla.edu.co',
            semester: 'Semestre VI',
          ),
          const SizedBox(height: 12),

          // More Records Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '+21 estudiantes adicionales verificados',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: AppTheme.textSecondary, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStudentRow({
    required String name,
    required String details,
    required String semester,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
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
                      decoration: BoxDecoration(
                        color: _surfaceHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: AppTheme.textSecondary, size: 24),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _tertiaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: _surfaceControl, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        details,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tertiaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BLE Listo',
                  style: TextStyle(
                    color: _tertiaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                semester,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicRuleCallout() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _systemAmber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info, color: _systemAmber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Regla Institucional Chairá (Acuerdo 014)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(text: 'Al finalizar la importación, el sistema asignará el cupo estandarizado de '),
                      TextSpan(
                        text: '6 inasistencias máximas (20%)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' antes de la notificación de cancelación de materia.'),
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

  Widget _buildPrimaryActionButtons(BuildContext context) {
    // Definimos la apariencia del botón primario según el estado de la animación
    Color btnBgColor = _primaryIndigo;
    Color btnTextColor = Colors.white;
    Widget btnContent = const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_sync, size: 20),
        SizedBox(width: 8),
        Text(
          'Importar 24 Estudiantes al Curso',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ],
    );

    if (_isImporting) {
      btnBgColor = _primaryIndigo.withValues(alpha: 0.9);
      btnContent = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 10),
          Text(
            'Enrolando 24 Registros...',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      );
    } else if (_isSuccess) {
      btnBgColor = _tertiaryContainer;
      btnTextColor = const Color(0xFFCDFFCA); // on-tertiary-container
      btnContent = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: btnTextColor, size: 20),
          const SizedBox(width: 8),
          Text(
            '¡Sincronización Exitosa!',
            style: TextStyle(color: btnTextColor, fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Column(
      children: [
        ElevatedButton(
          onPressed: _handleImportAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: btnBgColor,
            foregroundColor: btnTextColor,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: _isSuccess ? 0 : 4,
            shadowColor: _primaryIndigo.withValues(alpha: 0.3),
            padding: EdgeInsets.zero,
          ),
          child: btnContent,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}