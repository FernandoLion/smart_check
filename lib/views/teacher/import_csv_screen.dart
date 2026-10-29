import 'package:flutter/material.dart';
import '../../models/inscrito_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/csv_inscritos.dart';

/// Importa estudiantes pegando una lista copiada de Excel o de un CSV.
/// Al confirmar devuelve la lista de [Inscrito] con `Navigator.pop`.
class ImportCsvScreen extends StatefulWidget {
  final String courseName;

  const ImportCsvScreen({super.key, this.courseName = ''});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  static const Color _surfaceBg = Color(0xFF131315);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _primaryLight = Color(0xFFC2C1FF);
  static const Color _primaryIndigo = Color(0xFF5E5CE6);
  static const Color _tertiaryGreen = Color(0xFF47E266);
  static const Color _systemAmber = Color(0xFFFF9F0A);

  final _textoController = TextEditingController();
  ResultadoCsv _resultado = const ResultadoCsv([], []);

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  void _alCambiarTexto(String texto) {
    setState(() => _resultado = parsearInscritos(texto));
  }

  void _confirmar() {
    if (_resultado.inscritos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pega al menos un estudiante con cédula o correo'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    Navigator.pop<List<Inscrito>>(context, _resultado.inscritos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildInstrucciones(),
                  const SizedBox(height: 16),
                  _buildAreaTexto(),
                  const SizedBox(height: 16),
                  _buildResumen(),
                  if (_resultado.inscritos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildVistaPrevia(),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _confirmar,
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(
                      _resultado.inscritos.isEmpty
                          ? 'Agregar estudiantes'
                          : 'Agregar ${_resultado.inscritos.length} estudiantes',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryIndigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
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
      child: Row(
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
                  style: TextStyle(color: _primaryLight, fontSize: 17),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Importar Estudiantes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.courseName.isNotEmpty)
                  Text(
                    widget.courseName,
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
          GestureDetector(
            onTap: _confirmar,
            child: const Text(
              'Confirmar',
              style: TextStyle(
                color: _primaryLight,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstrucciones() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.table_chart_outlined, color: _tertiaryGreen, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Copia desde Excel las filas de los estudiantes junto con la '
              'fila de títulos (DOCUMENTO, NOMBRECOMPLETO, MAIL_INST...) y '
              'pégalas aquí. Solo se guardan la cédula, el nombre y el '
              'correo; las demás columnas se ignoran.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaTexto() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceControl,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _textoController,
        onChanged: _alCambiarTexto,
        minLines: 8,
        maxLines: 14,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Cédula;Nombre;Correo\n'
              '1117000000;Ana María Pérez Gómez;an.perez@udla.edu.co',
          hintStyle: TextStyle(color: AppTheme.textTertiary),
        ),
      ),
    );
  }

  Widget _buildResumen() {
    final total = _resultado.inscritos.length;
    final errores = _resultado.errores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              total > 0 ? Icons.check_circle_outline : Icons.info_outline,
              color: total > 0 ? _tertiaryGreen : AppTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              total == 1
                  ? '1 estudiante detectado'
                  : '$total estudiantes detectados',
              style: TextStyle(
                color: total > 0 ? _tertiaryGreen : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (_resultado.conEncabezado)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Cédula: ${_resultado.columnaCedula ?? '—'}  •  '
              'Nombre: ${_resultado.columnaNombre ?? 'usuario del correo'}  •  '
              'Correo: ${_resultado.columnaCorreo ?? '—'}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        for (final error in errores.take(5))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: const TextStyle(color: _systemAmber, fontSize: 13),
            ),
          ),
        if (errores.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'y ${errores.length - 5} filas más sin cédula ni correo.',
              style: const TextStyle(color: _systemAmber, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildVistaPrevia() {
    final visibles = _resultado.inscritos.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (final inscrito in visibles)
            ListTile(
              dense: true,
              title: Text(
                inscrito.nombre,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                inscrito.claves.join(' • '),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          if (_resultado.inscritos.length > visibles.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'y ${_resultado.inscritos.length - visibles.length} más',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
