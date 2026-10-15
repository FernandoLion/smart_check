import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AddStudentsModal extends StatelessWidget {
  final String courseName;
  final VoidCallback? onImportCsvTap;
  final VoidCallback? onManualCedulaTap;

  const AddStudentsModal({
    super.key,
    this.courseName = 'Ingeniería de Software II (Grupo 302-B)',
    this.onImportCsvTap,
    this.onManualCedulaTap,
  });

  // Helper estático para abrir el modal desde cualquier pantalla (10, 11 o 14)
  static Future<void> show(
    BuildContext context, {
    String courseName = 'Ingeniería de Software II (Grupo 302-B)',
    VoidCallback? onImportCsvTap,
    VoidCallback? onManualCedulaTap,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddStudentsModal(
        courseName: courseName,
        onImportCsvTap: onImportCsvTap,
        onManualCedulaTap: onManualCedulaTap,
      ),
    );
  }

  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _secondaryBlue = Color(0xFF3E90FF);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: _surfaceElevated.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. iOS Native Grabber Pill Bar
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // 2. Sheet Header with Title & Dismiss Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agregar Estudiantes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Selecciona cómo deseas registrar a los alumnos en ',
                                ),
                                TextSpan(
                                  text: courseName,
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
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. MAIN CONTENT: 2 Large Horizontal Option Cards
              Row(
                children: [
                  // CARD 1: Importar CSV de Chairá
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (onImportCsvTap != null) {
                          onImportCsvTap!();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Ir a Pantalla 13: Importar CSV Chairá',
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 175),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceControl,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Micro-badge Top Right
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _tertiaryGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _tertiaryGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Oficial UDLA',
                                  style: TextStyle(
                                    color: _tertiaryGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Icon Badge
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _tertiaryContainer.withValues(alpha: 0.35),
                                    _tertiaryGreen.withValues(alpha: 0.12),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _tertiaryGreen.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.table_chart_outlined,
                                color: _tertiaryGreen,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Title & Description
                            const Column(
                              children: [
                                Text(
                                  'Importar CSV Chairá',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Carga masiva oficial desde el sistema académico',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // CARD 2: Ingresar Cédula
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (onManualCedulaTap != null) {
                          onManualCedulaTap!();
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 175),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceControl,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Micro-badge Top Right
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: const Text(
                                  'Manual',
                                  style: TextStyle(
                                    color: Color(0xFFC7C4D7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Icon Badge
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _primaryIndigo.withValues(alpha: 0.35),
                                    _secondaryBlue.withValues(alpha: 0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _primaryIndigo.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.dialpad,
                                color: _primaryLight,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Title & Description
                            const Column(
                              children: [
                                Text(
                                  'Ingresar Cédula',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Búsqueda individual instantánea por documento',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Helpful Institutional Sync Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceElevated.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _surfaceControl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: _tertiaryGreen,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Sincronización directa con base de datos institucional ',
                            ),
                            TextSpan(
                              text: 'Chairá 2025-1',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '. Los derechos de matrícula serán validados en tiempo real.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Action Button (Cancelar)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _surfaceControl,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}