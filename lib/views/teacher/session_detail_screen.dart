import 'package:flutter/material.dart';

import '../../models/curso_model.dart';
import '../../models/sesion_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/course_detail_viewmodel.dart';
import '../../widgets/texto_sin_cortes.dart';

/// Una clase que ya pasó: quién vino, cómo quedó marcado cada uno y, para
/// quien quedó mal, la corrección a mano.
///
/// Todo sale de [vm], el mismo que alimenta el detalle del curso, así que una
/// corrección se ve al instante aquí y en el resumen del curso.
class SessionDetailScreen extends StatefulWidget {
  final Curso curso;
  final CourseDetailViewModel vm;

  /// La franja del horario que agrupa los llamados de esta clase.
  final DateTime franja;

  /// "Martes 18 de marzo de 2026".
  final String fechaTitulo;

  /// "Llamado 08:02 - 08:12".
  final String horario;

  const SessionDetailScreen({
    super.key,
    required this.curso,
    required this.vm,
    required this.franja,
    required this.fechaTitulo,
    required this.horario,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  // Colores exactos del HTML de Stitch
  static const Color _surfaceOled = Color(0xFF000000);
  static const Color _surfaceContainer = Color(0xFF1F1F21);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceControl = Color(0xFF2C2C2E);
  static const Color _surfaceHigh = Color(0xFF2A2A2C);
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryLight = Color(0xFFC2C1FF); // primary
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _tertiaryContainer = Color(0xFF00802D);
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _errorContainer = Color(0xFF93000A);

  int _selectedFilter = 0; // 0: Todos, 1: Presentes, 2: Ausentes

  /// Los inscritos cuya corrección se está guardando.
  final _corrigiendo = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceOled,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.vm,
          builder: (context, _) {
            final filas = widget.vm.detalleDeFranja(widget.franja);
            final presentes = filas.where((f) => f.presente).toList();
            final visibles = filas.where((f) {
              if (_selectedFilter == 1) return f.presente;
              if (_selectedFilter == 2) return !f.presente;
              return true;
            }).toList();
            return Column(
              children: [
                _buildTopHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      _buildHeroSummaryCard(filas.length, presentes),
                      const SizedBox(height: 16),
                      _buildComoSeMarco(presentes),
                      const SizedBox(height: 16),
                      _buildFilterSegmentedControl(
                        filas.length,
                        presentes.length,
                      ),
                      const SizedBox(height: 16),
                      _buildStudentsListSection(visibles),
                      const SizedBox(height: 20),
                      _buildPie(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(color: _surfaceOled.withValues(alpha: 0.9)),
      // Altura mínima, no fija: con letra grande el título y el subtítulo
      // necesitan más.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios, color: _primaryIndigo, size: 18),
                  Text(
                    'Curso',
                    style: TextStyle(color: _primaryIndigo, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  ),
                  Text(
                    '${widget.curso.codigo} • Grupo ${widget.curso.grupo}',
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
            // Equilibra el botón de volver para que el título quede centrado.
            const SizedBox(width: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSummaryCard(int total, List<FilaDeSesion> presentes) {
    final ausentes = total - presentes.length;
    final aMano = presentes
        .where((f) => f.marca!.metodo == MetodoAsistencia.manual)
        .length;
    final llamados = widget.vm.llamadosDeFranja(widget.franja);
    final porcentaje = total == 0 ? null : presentes.length * 100 / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    color: _tertiaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available, color: _tertiaryGreen, size: 15),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Clase terminada',
                          style: TextStyle(
                            color: _tertiaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                llamados == 1 ? '1 llamado' : '$llamados llamados',
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.fechaTitulo,
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
              const Icon(Icons.schedule, color: AppTheme.textTertiary, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.horario,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAula(),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${presentes.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ $total inscritos',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                porcentaje == null
                    ? 'Sin inscritos'
                    : '${porcentaje.round()}% asistió',
                style: const TextStyle(
                  color: _tertiaryGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? Container(color: _surfaceControl)
                  : Row(
                      children: [
                        if (presentes.isNotEmpty)
                          Expanded(
                            flex: presentes.length,
                            child: Container(color: _tertiaryGreen),
                          ),
                        if (presentes.isNotEmpty && ausentes > 0)
                          const SizedBox(width: 2),
                        if (ausentes > 0)
                          Expanded(
                            flex: ausentes,
                            child: Container(color: _systemRed),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatMiniCard(
                  label: 'Presentes',
                  value: '${presentes.length}',
                  valueColor: _tertiaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatMiniCard(
                  label: 'Ausentes',
                  value: '$ausentes',
                  valueColor: _systemRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatMiniCard(
                  label: 'A mano',
                  value: '$aMano',
                  valueColor: _systemAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// El aula del curso y si tiene geocerca. Es la configuración del curso,
  /// no una comprobación: lo que se comprobó en cada marca no se guarda.
  Widget _buildAula() {
    final aula = widget.curso.aula.trim();
    final conGeocerca = widget.curso.geocerca != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceControl.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              color: _primaryLight,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aula.isEmpty ? 'Sin aula registrada' : aula,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  conGeocerca
                      ? 'El curso tiene geocerca'
                      : 'El curso no tiene geocerca',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: _surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextoSinCortes(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// De los presentes, cuántos los detectó el radar y cuántos se marcaron a
  /// mano.
  Widget _buildComoSeMarco(List<FilaDeSesion> presentes) {
    final ble = presentes
        .where((f) => f.marca!.metodo == MetodoAsistencia.ble)
        .length;
    final manual = presentes.length - ble;
    String parte(int n) => presentes.isEmpty
        ? '—'
        : '${(n * 100 / presentes.length).round()}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, color: _primaryLight, size: 18),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'CÓMO SE MARCÓ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFilaMetodo(
            icono: Icons.sensors,
            color: _primaryLight,
            titulo: 'Radar BLE',
            detalle: 'Firmó desde su celular y el radar lo oyó en el aula',
            cantidad: ble,
            parte: parte(ble),
          ),
          const SizedBox(height: 8),
          _buildFilaMetodo(
            icono: Icons.edit_note,
            color: _systemAmber,
            titulo: 'A mano',
            detalle: 'Lo marcó el docente en el llamado o al corregir',
            cantidad: manual,
            parte: parte(manual),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaMetodo({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    required int cantidad,
    required String parte,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(12),
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
            child: Icon(icono, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$cantidad',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                parte,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSegmentedControl(int total, int presentes) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceControl,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentTab(0, 'Todos ($total)'),
          _buildSegmentTab(1, 'Presentes ($presentes)'),
          _buildSegmentTab(2, 'Ausentes (${total - presentes})'),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, String label) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: TextoSinCortes(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsListSection(List<FilaDeSesion> filas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'INSCRITOS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (filas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nadie en esta lista.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
              ),
            ),
          ),
        for (final fila in filas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildStudentRecordCard(fila),
          ),
      ],
    );
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (partes.isEmpty) return '?';
    final segunda = partes.length >= 3 ? partes[2] : partes.last;
    return partes.length == 1
        ? partes.first[0].toUpperCase()
        : '${partes.first[0]}${segunda[0]}'.toUpperCase();
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Widget _buildStudentRecordCard(FilaDeSesion fila) {
    final marca = fila.marca;
    final porRadar = fila.presente && marca!.metodo == MetodoAsistencia.ble;
    final guardando = _corrigiendo.contains(fila.inscrito.clave);

    final Color punto;
    final Color fondoInsignia;
    final Color textoInsignia;
    final IconData? iconoInsignia;
    final String insignia;
    if (!fila.presente) {
      punto = _systemRed;
      fondoInsignia = _errorContainer.withValues(alpha: 0.35);
      textoInsignia = _systemRed;
      iconoInsignia = null;
      insignia = 'Ausente';
    } else if (porRadar) {
      punto = _tertiaryGreen;
      fondoInsignia = _tertiaryContainer.withValues(alpha: 0.25);
      textoInsignia = _tertiaryGreen;
      iconoInsignia = Icons.sensors;
      insignia = 'BLE';
    } else {
      punto = _systemAmber;
      fondoInsignia = _systemAmber.withValues(alpha: 0.2);
      textoInsignia = _systemAmber;
      iconoInsignia = Icons.edit_note;
      insignia = 'A mano';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
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
                  color: _surfaceControl,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _iniciales(fila.inscrito.nombre),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: -3,
                right: -3,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: punto,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    fila.presente ? Icons.check : Icons.close,
                    size: 10,
                    color: fila.presente ? Colors.black : Colors.white,
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
                  fila.inscrito.nombre,
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
                  fila.inscrito.cedula ?? fila.inscrito.email ?? '',
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fondoInsignia,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconoInsignia != null) ...[
                      Icon(iconoInsignia, color: textoInsignia, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      insignia,
                      style: TextStyle(
                        color: textoInsignia,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (guardando)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GestureDetector(
                  onTap: () => _corregir(fila),
                  child: Text(
                    fila.presente ? _hora(marca!.hora) : 'Marcar presente',
                    style: TextStyle(
                      color: fila.presente
                          ? AppTheme.textTertiary
                          : _primaryLight,
                      fontSize: 12,
                      fontWeight: fila.presente
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cambia a mano el estado de [fila]. Dejar ausente a alguien que el radar
  /// detectó se confirma antes, porque deshace una marca que sí ocurrió.
  Future<void> _corregir(FilaDeSesion fila) async {
    final presente = !fila.presente;
    if (!presente) {
      final confirma = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Text(
            '¿Dejarlo ausente?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${fila.inscrito.nombre} quedará ausente en esta clase. La '
            'corrección se guarda como marca manual a tu nombre.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogo, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Dejar ausente'),
            ),
          ],
        ),
      );
      if (confirma != true || !mounted) return;
    }

    final clave = fila.inscrito.clave;
    setState(() => _corrigiendo.add(clave));
    final error = await widget.vm.corregirAsistencia(
      widget.franja,
      fila.inscrito,
      presente: presente,
      docenteUid: widget.curso.docenteUid,
    );
    if (!mounted) return;
    setState(() => _corrigiendo.remove(clave));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (presente
                  ? '${fila.inscrito.nombre} quedó presente.'
                  : '${fila.inscrito.nombre} quedó ausente.'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPie() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, color: AppTheme.textTertiary, size: 14),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Las correcciones quedan guardadas como marca manual a tu nombre.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
