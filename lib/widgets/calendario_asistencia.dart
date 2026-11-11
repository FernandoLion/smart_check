import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
import '../models/calendario_academico.dart';
import '../models/sesion_model.dart';
import '../utils/app_theme.dart';

// --- La cuadrícula, que comparten el estudiante y el docente ----------------

const _nombresDeMes = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
const _diasCortos = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _diasLargos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// "noviembre", para las frases del resumen del mes.
String nombreDelMes(DateTime mes) => _nombresDeMes[mes.month - 1].toLowerCase();

/// "Lunes 2 de noviembre".
String tituloDelDia(DateTime fecha) =>
    '${_diasLargos[fecha.weekday - 1]} ${fecha.day} de ${nombreDelMes(fecha)}';

String horaCorta(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// Hasta qué mes dejan llegar las flechas: el siguiente al de hoy, sin pasar
/// del último mes del semestre.
DateTime ultimoMesDelCalendario(DateTime hoy, Semestre? semestre) {
  final siguiente = DateTime(hoy.year, hoy.month + 1);
  if (semestre == null) return siguiente;
  final ultimo = DateTime(semestre.fin.year, semestre.fin.month);
  return siguiente.isAfter(ultimo) ? ultimo : siguiente;
}

/// Cómo se pinta un día: relleno si ya pasó algo, con contorno si no.
class DiaPintado {
  final Color color;
  final bool relleno;

  /// Texto pequeño debajo del número, como el porcentaje del grupo.
  final String? nota;

  /// Lo que lee el lector de pantalla.
  final String descripcion;

  const DiaPintado({
    required this.color,
    required this.relleno,
    required this.descripcion,
    this.nota,
  });
}

class ItemLeyenda {
  final Color color;
  final bool relleno;
  final String texto;

  const ItemLeyenda(this.color, this.texto, {this.relleno = true});
}

/// Un mes con sus días pintados, flechas para cambiar de mes, leyenda,
/// resumen y el detalle del día que se toque. Qué significa cada color lo
/// decide quien lo usa.
class CalendarioMensual extends StatefulWidget {
  final DateTime hoy;

  /// Hasta dónde dejan llegar las flechas.
  final DateTime primerMes;
  final DateTime ultimoMes;

  final Map<int, DiaPintado> Function(DateTime mes) diasDe;
  final List<ItemLeyenda> leyenda;
  final String Function(DateTime mes) resumenDe;
  final Widget Function(DateTime fecha) detalleDe;

  /// Días cuadrados, con espacio para [DiaPintado.nota].
  final bool cuadrado;

  const CalendarioMensual({
    super.key,
    required this.hoy,
    required this.primerMes,
    required this.ultimoMes,
    required this.diasDe,
    required this.leyenda,
    required this.resumenDe,
    required this.detalleDe,
    this.cuadrado = false,
  });

  @override
  State<CalendarioMensual> createState() => _CalendarioMensualState();
}

class _CalendarioMensualState extends State<CalendarioMensual> {
  late DateTime _mes = _mesInicial;
  int? _seleccionado;

  DateTime get _mesInicial {
    final actual = DateTime(widget.hoy.year, widget.hoy.month);
    return actual.isAfter(widget.ultimoMes) ? widget.ultimoMes : actual;
  }

  bool get _hayAnterior => _mes.isAfter(widget.primerMes);
  bool get _haySiguiente => _mes.isBefore(widget.ultimoMes);

  void _moverMes(int delta) => setState(() {
        _mes = DateTime(_mes.year, _mes.month + delta);
        _seleccionado = null;
      });

  @override
  Widget build(BuildContext context) {
    final dias = widget.diasDe(_mes);
    final seleccionado = _seleccionado;
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
          _cuadricula(dias),
          const SizedBox(height: 12),
          _leyenda(),
          const SizedBox(height: 10),
          Text(
            widget.resumenDe(_mes),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          // El día pudo dejar de estar pintado si cambiaron los datos.
          if (seleccionado != null && dias.containsKey(seleccionado)) ...[
            const SizedBox(height: 10),
            widget.detalleDe(DateTime(_mes.year, _mes.month, seleccionado)),
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
            '${_nombresDeMes[_mes.month - 1]} ${_mes.year}',
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

  Widget _cuadricula(Map<int, DiaPintado> dias) {
    final hoy = widget.hoy;
    final diasDelMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final huecos = DateTime(_mes.year, _mes.month).weekday - 1;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
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
            dias[d],
            esHoy: hoy.year == _mes.year &&
                hoy.month == _mes.month &&
                hoy.day == d,
          ),
      ],
    );
  }

  Widget _dia(int d, DiaPintado? dia, {required bool esHoy}) {
    final relleno = dia?.relleno ?? false;
    final seleccionado = _seleccionado == d;
    final Color colorTexto;
    if (relleno) {
      colorTexto = Colors.black;
    } else if (dia != null) {
      colorTexto = Color.lerp(dia.color, Colors.white, 0.5)!;
    } else {
      colorTexto = AppTheme.textSecondary;
    }
    final borde = Border.all(
      color: seleccionado
          ? Colors.white
          : esHoy
              ? Colors.white.withValues(alpha: 0.7)
              : dia != null && !relleno
                  ? dia.color
                  : Colors.transparent,
      width: seleccionado ? 2.5 : 1.5,
    );
    return Semantics(
      button: dia != null,
      label: '$d${dia == null ? '' : ', ${dia.descripcion}'}',
      child: GestureDetector(
        onTap: dia == null
            ? null
            : () => setState(() => _seleccionado = seleccionado ? null : d),
        child: Container(
          decoration: BoxDecoration(
            shape: widget.cuadrado ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: widget.cuadrado ? BorderRadius.circular(10) : null,
            color: relleno ? dia!.color.withValues(alpha: 0.85) : null,
            border: borde,
          ),
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    color: colorTexto,
                    fontSize: 14,
                    fontWeight:
                        relleno || esHoy ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (dia?.nota != null)
                  Text(
                    dia!.nota!,
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leyenda() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final item in widget.leyenda)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.relleno ? item.color : null,
                  border: item.relleno
                      ? null
                      : Border.all(color: item.color, width: 1.5),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                item.texto,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// El recuadro con el detalle del día tocado.
class PanelDelDia extends StatelessWidget {
  final String titulo;
  final List<Widget> hijos;

  const PanelDelDia({super.key, required this.titulo, required this.hijos});

  @override
  Widget build(BuildContext context) {
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
          ...hijos,
        ],
      ),
    );
  }
}

// --- El calendario del estudiante en una materia ----------------------------

/// Cómo le fue al estudiante un día del calendario.
enum EstadoDia {
  /// Asistió a todas las clases de ese día, a tiempo.
  asistio,

  /// Llegó tarde, o asistió a una clase del día y faltó a otra.
  parcial,

  /// Faltó a todas las clases de ese día.
  falto,

  /// El docente le justificó la falta (todas las clases de ese día).
  justificada,

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
  Semestre? semestre,
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
    // Fuera de las fechas del semestre no hay clases que esperar.
    if (semestre != null && !semestre.contiene(fecha)) continue;
    if (diasDeClase.contains(fecha.weekday)) estados[d] = EstadoDia.proxima;
  }
  return estados;
}

EstadoDia _estadoDe(List<ClaseDelEstudiante> clases) {
  final asistidas = clases.where((c) => c.asistio).length;
  final justificadas = clases.where((c) => c.justificada).length;
  // Las justificadas no cuentan: se juzga sobre las demás.
  final contables = clases.length - justificadas;
  if (contables == 0) return EstadoDia.justificada;
  if (asistidas == 0) return EstadoDia.falto;
  final tarde = clases.any((c) => c.marca?.estado == EstadoAsistencia.tarde);
  return asistidas < contables || tarde
      ? EstadoDia.parcial
      : EstadoDia.asistio;
}

/// El calendario mensual de asistencia de una materia, con los días
/// pintados según lo que pasó en cada clase. Se navega de mes en mes, desde
/// la primera clase hasta el mes siguiente al actual.
class CalendarioAsistencia extends StatelessWidget {
  static const _verde = Color(0xFF30D158);
  static const _ambar = Color(0xFFFF9F0A);
  static const _rojo = Color(0xFFFF453A);
  static const _azul = Color(0xFF0A84FF);
  static const _indigo = Color(0xFF5E5CE6);

  final List<ClaseDelEstudiante> clases;

  /// Los días de la semana con clase (1 = lunes), para marcar las próximas.
  final List<int> diasDeClase;

  final DateTime hoy;
  final Semestre? semestre;

  const CalendarioAsistencia({
    super.key,
    required this.clases,
    required this.diasDeClase,
    required this.hoy,
    this.semestre,
  });

  DateTime get _primerMes {
    if (clases.isEmpty) return DateTime(hoy.year, hoy.month);
    final primera =
        clases.map((c) => c.franja).reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(primera.year, primera.month);
  }

  static Color _color(EstadoDia e) => switch (e) {
        EstadoDia.asistio => _verde,
        EstadoDia.parcial => _ambar,
        EstadoDia.falto => _rojo,
        EstadoDia.justificada => _azul,
        EstadoDia.proxima => _indigo,
      };

  static String _texto(EstadoDia e) => switch (e) {
        EstadoDia.asistio => 'asistió',
        EstadoDia.parcial => 'tarde o a medias',
        EstadoDia.falto => 'faltó',
        EstadoDia.justificada => 'falta justificada',
        EstadoDia.proxima => 'próxima clase',
      };

  Map<int, EstadoDia> _estados(DateTime mes) => estadosDelMes(
        mes: mes,
        clases: clases,
        diasDeClase: diasDeClase,
        hoy: hoy,
        semestre: semestre,
      );

  Map<int, DiaPintado> _dias(DateTime mes) => _estados(mes).map(
        (d, e) => MapEntry(
          d,
          DiaPintado(
            color: _color(e),
            relleno: e != EstadoDia.proxima,
            descripcion: _texto(e),
          ),
        ),
      );

  String _resumen(DateTime mes) {
    // Las justificadas no se cuentan.
    final delMes = clases.where(
      (c) =>
          c.franja.year == mes.year &&
          c.franja.month == mes.month &&
          !c.justificada,
    );
    final asistio = delMes.where((c) => c.asistio).length;
    final falto = delMes.length - asistio;
    final nombre = nombreDelMes(mes);
    if (delMes.isEmpty) return 'En $nombre no hubo clases con llamado.';
    return 'En $nombre: asistió a $asistio de ${delMes.length} '
        '${delMes.length == 1 ? 'clase' : 'clases'}'
        '${falto > 0 ? ', faltó a $falto' : ''}.';
  }

  Widget _detalle(DateTime fecha) {
    final estado = _estados(fecha)[fecha.day];
    final delDia = clases
        .where(
          (c) =>
              c.franja.year == fecha.year &&
              c.franja.month == fecha.month &&
              c.franja.day == fecha.day,
        )
        .toList()
      ..sort((a, b) => a.franja.compareTo(b.franja));
    final lineas = delDia.isEmpty
        ? ['Clase programada según el horario.']
        : [for (final c in delDia) _lineaDeClase(c)];
    return PanelDelDia(
      titulo: tituloDelDia(fecha),
      hijos: [
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
    );
  }

  static String _lineaDeClase(ClaseDelEstudiante c) {
    final clase = 'Clase de las ${horaCorta(c.franja)}';
    final marca = c.marca;
    if (c.justificada) return '$clase: falta justificada, no se cuenta';
    if (!c.asistio) {
      return marca == null
          ? '$clase: faltó (sin marca)'
          : '$clase: marcado ausente por el docente';
    }
    final como = marca!.metodo == MetodoAsistencia.ble ? 'radar BLE' : 'a mano';
    final tarde = marca.estado == EstadoAsistencia.tarde ? 'llegó tarde, ' : '';
    return '$clase: ${tarde}asistió ($como, ${horaCorta(marca.hora)})';
  }

  @override
  Widget build(BuildContext context) {
    return CalendarioMensual(
      hoy: hoy,
      primerMes: _primerMes,
      ultimoMes: ultimoMesDelCalendario(hoy, semestre),
      diasDe: _dias,
      resumenDe: _resumen,
      detalleDe: _detalle,
      leyenda: const [
        ItemLeyenda(_verde, 'Asistió'),
        ItemLeyenda(_ambar, 'Tarde o a medias'),
        ItemLeyenda(_rojo, 'Faltó'),
        ItemLeyenda(_azul, 'Justificada'),
        ItemLeyenda(_indigo, 'Próxima clase', relleno: false),
      ],
    );
  }
}
