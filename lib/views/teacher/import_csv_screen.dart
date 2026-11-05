import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/inscrito_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/csv_inscritos.dart';
import '../../utils/hoja_de_calculo.dart';

/// Importa estudiantes desde el archivo de la lista de clase (.xls, .xlsx o
/// .csv) o pegando las filas copiadas de Excel. Al confirmar devuelve la
/// lista de [Inscrito] con `Navigator.pop`.
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

  /// El nombre del archivo leído, para que el docente vea cuál cargó.
  String? _archivo;
  bool _leyendo = false;

  static const _extensiones = ['xls', 'xlsx', 'csv', 'txt'];

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  void _alCambiarTexto(String texto) {
    setState(() => _resultado = parsearInscritos(texto));
  }

  /// Abre el selector del celular y vuelca el archivo en el área de texto,
  /// donde se ve qué se leyó y se puede corregir antes de confirmar. El
  /// formato se reconoce por el contenido; la extensión solo filtra lo que
  /// claramente no es una lista.
  Future<void> _elegirArchivo() async {
    final messenger = ScaffoldMessenger.of(context);
    void avisar(String mensaje) => messenger.showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: AppTheme.error),
        );

    final PlatformFile? archivo;
    try {
      archivo = await FilePicker.pickFile(
        dialogTitle: 'Lista de estudiantes',
      );
    } catch (e) {
      avisar('No se pudo abrir el selector de archivos: $e');
      return;
    }
    if (archivo == null || !mounted) return;
    final extension = (archivo.extension ?? '').toLowerCase();
    if (extension.isNotEmpty && !_extensiones.contains(extension)) {
      avisar('Elige la lista en Excel (.xls o .xlsx) o en CSV.');
      return;
    }

    setState(() => _leyendo = true);
    try {
      final texto = textoDesdeFilas(
        leerHojaDeCalculo(await archivo.readAsBytes()),
      );
      if (!mounted) return;
      _textoController.text = texto;
      setState(() {
        _archivo = archivo!.name;
        _resultado = parsearInscritos(texto);
      });
    } on FormatException catch (e) {
      avisar(e.message);
    } catch (e) {
      avisar('No se pudo leer el archivo: $e');
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
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
                  _buildElegirArchivo(),
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
      // Altura mínima, no fija: con letra grande el título y el subtítulo
      // necesitan más.
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
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
              'Elige el archivo de la lista de clase (el Excel de Chairá, '
              '.xls o .xlsx, o un CSV), o copia desde Excel las filas con la '
              'fila de títulos (DOCUMENTO, NOMBRECOMPLETO, MAIL_INST...) y '
              'pégalas abajo. Solo se guardan la cédula, el nombre y el '
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

  Widget _buildElegirArchivo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _leyendo ? null : _elegirArchivo,
          icon: _leyendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(
            _leyendo ? 'Leyendo el archivo...' : 'Elegir archivo (.xls, .xlsx o .csv)',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryLight,
            side: BorderSide(color: _primaryLight.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _archivo == null
              ? 'o pega la lista aquí:'
              : 'Leído de $_archivo. Puedes revisarlo abajo antes de agregar.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
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
          hintText:
              'Cédula;Nombre;Correo\n'
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
