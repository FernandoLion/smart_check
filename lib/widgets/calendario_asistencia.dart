import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
import '../models/sesion_model.dart';
import '../utils/app_theme.dart';

/// Cómo le fue al estudiante un día del calendario.
enum EstadoDia {
  /// Asistió a todas las clases de ese día, a tiempo.
  asistio,

  /// Llegó tarde, o asistió a una clase del día y faltó a otra.
  parcial,

  /// Faltó a todas las clases de ese día.
  falto,

  /// Hoy o más adelante le toca clase según el horario.
  proxima,
}

/// El estado de cada día de [mes] que tuvo o tendrá clase, por número de
/// día. Un día de horario que ya pasó sin llamado no aparece: esa clase no
/// se dictó (o no se pasó lista) y no cuenta.
Map<int, EstadoDia> estadosDelMes({
  required DateTime mes,
  required List<ClaseDelEstudiante> clases,
  required List<int> diasDeClase,
  required DateTime hoy,
}) {
  final porDia = <int, List<ClaseDelEstudiante>>{};
  for (final c in clases) {
    if (c.franja.year == mes.year && c.franja.month == mes.month) {
      (porDia[c.franja.day] ??= []).add(c);
    }
  }
  final estados = <int, EstadoDia>{
    for (final MapEntry(key: dia, value: lista) in porDia.entries)
      dia: _estadoDe(lista),
  };

  final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
  final ultimo = DateTime(mes.year, mes.month + 1, 0).day;
  for (var d = 1; d <= ultimo; d++) {
    final fecha = DateTime(mes.year, mes.month, d);
    if (fecha.isBefore(hoyDia) || estados.containsKey(d)) continue;
    if (diasDeClase.contains(fecha.weekday)) estados[d] = EstadoDia.proxima;
  }
  return estados;
}

EstadoDia _estadoDe(List<ClaseDelEstudiante> clases) {
  final asistidas = clases.where((c) => c.asistio).length;
  if (asistidas == 0) return EstadoDia.falto;
  final tarde = clases.any((c) => c.marca?.estado == EstadoAsistencia.tarde);
  return asistidas < clases.length || tarde
      ? EstadoDia.parcial
      : EstadoDia.asistio;
}

/// El calendario mensual de asistencia de una materia, con los días
/// pintados según lo que pasó en cada clase. Se navega de mes en mes, desde
/// la primera clase hasta el mes siguiente al actual.
class CalendarioAsistencia extends StatefulWidget {
  final List<ClaseDelEstudiante> clases;

  /// Los días de la semana con clase (1 = lunes), para marcar las próximas.
  final List<int> diasDeClase;

  final DateTime hoy;

  const CalendarioAsistencia({
    super.key,
    required this.clases,
    required this.diasDeClase,
    required this.hoy,
  });

  @override
  State<CalendarioAsistencia> createState() => _CalendarioAsistenciaState();
}

class _CalendarioAsistenciaState extends State<CalendarioAsistencia> {
  static const _verde = Color(0xFF30D158);
  static const _ambar = Color(0xFFFF9F0A);
  static const _rojo = Color(0xFFFF453A);
  static const _indigo = Color(0xFF5E5CE6);

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _diasCortos = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _diasLargos = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  late DateTime _mes = DateTime(widget.hoy.year, widget.hoy.month);
  int? _seleccionado;

  DateTime get _primerMes {
    if (widget.clases.isEmpty) return DateTime(widget.hoy.year, widget.hoy.month);
    final primera = widget.clases
        .map((c) => c.franja)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(primera.year, primera.month);
  }

  DateTime get _ultimoMes => DateTime(widget.hoy.year, widget.hoy.month + 1);

  bool get _hayAnterior => _mes.isAfter(_primerMes);
  bool get _haySiguiente => _mes.isBefore(_ultimoMes);

  void _moverMes(int delta) => setState(() {
        _mes = DateTime(_mes.year, _mes.month + delta);
        _seleccionado = null;
      });

  static Color _color(EstadoDia e) => switch (e) {
        EstadoDia.asistio => _verde,
        EstadoDia.parcial => _ambar,
        EstadoDia.falto => _rojo,
        EstadoDia.proxima => _indigo,
      };

  @override
  Widget build(BuildContext context) {
    final estados = estadosDelMes(
      mes: _mes,
      clases: widget.clases,
      diasDeClase: widget.diasDeClase,
      hoy: widget.hoy,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(),
          const SizedBox(height: 4),
          _cuadricula(estados),
          const SizedBox(height: 12),
          _leyenda(),
          const SizedBox(height: 10),
          _resumen(estados),
          if (_seleccionado != null) ...[
            const SizedBox(height: 10),
            _detalleDelDia(_seleccionado!, estados[_seleccionado!]),
          ],
        ],
      ),
    );
  }

  Widget _encabezado() {
    return Row(
      children: [
        IconButton(
          onPressed: _hayAnterior ? () => _moverMes(-1) : null,
          icon: const Icon(Icons.chevron_left),
          color: Colors.white,
          disabledColor: AppTheme.textTertiary,
          tooltip: 'Mes anterior',
        ),
        Expanded(
          child: Text(
            '${_meses[_mes.month - 1]} ${_mes.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: _haySiguiente ? () => _moverMes(1) : null,
          icon: const Icon(Icons.chevron_right),
          color: Colors.white,
          disabledColor: AppTheme.textTertiary,
          tooltip: 'Mes siguiente',
        ),
      ],
    );
  }

  Widget _cuadricula(Map<int, EstadoDia> estados) {
    final hoy = widget.hoy;
    final diasDelMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final huecos = DateTime(_mes.year, _mes.month).weekday - 1;
    final celdas = <Widget>[
      for (final d in _diasCortos)
        Center(
          child: Text(
            d,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      for (var i = 0; i < huecos; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasDelMes; d++)
        _dia(
          d,
          estados[d],
          esHoy: hoy.year == _mes.year && hoy.month == _mes.month && hoy.day == d,
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: celdas,
    );
  }

  Widget _dia(int d, EstadoDia? estado, {required bool esHoy}) {
    final color = estado == null ? null : _color(estado);
    final relleno = estado != null && estado != EstadoDia.proxima;
    final seleccionado = _seleccionado == d;
    return Semantics(
      button: estado != null,
      label: '$d${estado == null ? '' : ', ${_texto(estado)}'}',
      child: GestureDetector(
        onTap: estado == null
            ? null
            : () => setState(() => _seleccionado = seleccionado ? null : d),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: relleno ? color!.withValues(alpha: 0.85) : null,
            border: Border.all(
              color: seleccionado
                  ? Colors.white
                  : esHoy
                      ? Colors.white.withValues(alpha: 0.7)
                      : estado == EstadoDia.proxima
                          ? _indigo
                          : Colors.transparent,
              width: seleccionado ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            child: Text(
              '$d',
              style: TextStyle(
                color: relleno
                    ? Colors.black
                    : estado == EstadoDia.proxima
                        ? const Color(0xFFC2C1FF)
                        : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: relleno || esHoy ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _texto(EstadoDia e) => switch (e) {
        EstadoDia.asistio => 'asistió',
        EstadoDia.parcial => 'tarde o a medias',
        EstadoDia.falto => 'faltó',
        EstadoDia.proxima => 'próxima clase',
      };

  Widget _leyenda() {
    Widget item(EstadoDia e, String texto) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: e == EstadoDia.proxima ? null : _color(e),
                border: e == EstadoDia.proxima
                    ? Border.all(color: _indigo, width: 1.5)
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              texto,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        item(EstadoDia.asistio, 'Asistió'),
        item(EstadoDia.parcial, 'Tarde o a medias'),
        item(EstadoDia.falto, 'Faltó'),
        item(EstadoDia.proxima, 'Próxima clase'),
      ],
    );
  }

  Widget _resumen(Map<int, EstadoDia> estados) {
    final delMes = widget.clases.where(
      (c) => c.franja.year == _mes.year && c.franja.month == _mes.month,
    );
    final asistio = delMes.where((c) => c.asistio).length;
    final falto = delMes.length - asistio;
    final mes = _meses[_mes.month - 1].toLowerCase();
    final texto = delMes.isEmpty
        ? 'En $mes no hubo clases con llamado.'
        : 'En $mes: asistió a $asistio de ${delMes.length} '
            '${delMes.length == 1 ? 'clase' : 'clases'}'
            '${falto > 0 ? ', faltó a $falto' : ''}.';
    return Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    );
  }

  Widget _detalleDelDia(int d, EstadoDia? estado) {
    final fecha = DateTime(_mes.year, _mes.month, d);
    final titulo = '${_diasLargos[fecha.weekday - 1]} $d de '
        '${_meses[_mes.month - 1].toLowerCase()}';
    final clases = widget.clases
        .where(
          (c) =>
              c.franja.year == fecha.year &&
              c.franja.month == fecha.month &&
              c.franja.day == d,
        )
        .toList()
      ..sort((a, b) => a.franja.compareTo(b.franja));
    final lineas = clases.isEmpty
        ? ['Clase programada según el horario.']
        : [for (final c in clases) _lineaDeClase(c)];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l,
                style: TextStyle(
                  color: estado == null ? AppTheme.textSecondary : _color(estado),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  static String _lineaDeClase(ClaseDelEstudiante c) {
    final clase = 'Clase de las ${_hora(c.franja)}';
    final marca = c.marca;
    if (!c.asistio) {
      return marca == null
          ? '$clase: faltó (sin marca)'
          : '$clase: marcado ausente por el docente';
    }
    final como = marca!.metodo == MetodoAsistencia.ble ? 'radar BLE' : 'a mano';
    final tarde = marca.estado == EstadoAsistencia.tarde ? 'llegó tarde, ' : '';
    return '$clase: ${tarde}asistió ($como, ${_hora(marca.hora)})';
  }
}
