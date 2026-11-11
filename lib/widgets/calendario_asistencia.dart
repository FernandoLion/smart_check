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
const _diasCortos = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
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

/// Cómo se dibuja un día con algo que decir.
enum EstiloDia {
  /// Círculo relleno con sombra: ya pasó algo (asistió, faltó...).
  relleno,

  /// Solo el borde del círculo: algo que tocaba y no ocurrió (sin llamado).
  aro,

  /// Un punto bajo el número: algo que viene (próxima clase).
  punto,
}

/// Cómo se pinta un día.
class DiaPintado {
  final Color color;
  final EstiloDia estilo;

  /// Lo que lee el lector de pantalla.
  final String descripcion;

  const DiaPintado({
    required this.color,
    required this.descripcion,
    this.estilo = EstiloDia.relleno,
  });
}

class ItemLeyenda {
  final Color color;
  final String texto;
  final EstiloDia estilo;

  const ItemLeyenda(this.color, this.texto, {this.estilo = EstiloDia.relleno});
}

/// Un mes con sus días pintados, con el estilo diseñado en Stitch: círculos
/// de color con sombra, los días de los meses vecinos atenuados, "Hoy" con
/// aro índigo, botones redondos para cambiar de mes, chip del periodo,
/// leyenda y, al tocar un día, su detalle. Con [historial], un selector
/// "Vista Mes | Historial Completo" alterna con esa lista. Qué significa
/// cada color lo decide quien lo usa.
class CalendarioMensual extends StatefulWidget {
  final DateTime hoy;

  /// Hasta dónde dejan llegar las flechas.
  final DateTime primerMes;
  final DateTime ultimoMes;

  final Map<int, DiaPintado> Function(DateTime mes) diasDe;
  final List<ItemLeyenda> leyenda;
  final String Function(DateTime mes) resumenDe;
  final Widget Function(DateTime fecha) detalleDe;

  /// "2026-2", para el chip junto al mes.
  final String? periodo;

  /// La lista completa de clases, para la pestaña "Historial Completo".
  final Widget? historial;

  const CalendarioMensual({
    super.key,
    required this.hoy,
    required this.primerMes,
    required this.ultimoMes,
    required this.diasDe,
    required this.leyenda,
    required this.resumenDe,
    required this.detalleDe,
    this.periodo,
    this.historial,
  });

  @override
  State<CalendarioMensual> createState() => _CalendarioMensualState();
}

class _CalendarioMensualState extends State<CalendarioMensual> {
  static const _indigo = Color(0xFF5E5CE6);
  static const _indigoClaro = Color(0xFFE2DFFF);
  static const _borde = Color(0x14FFFFFF); // Blanco al 8 %.

  late DateTime _mes = _mesInicial;
  int? _seleccionado;
  bool _verHistorial = false;

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
    final historial = widget.historial;
    final verHistorial = _verHistorial && historial != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (historial != null) ...[
            _selector(),
            const SizedBox(height: 16),
          ],
          if (verHistorial) historial else ..._vistaMes(),
        ],
      ),
    );
  }

  List<Widget> _vistaMes() {
    final dias = widget.diasDe(_mes);
    final seleccionado = _seleccionado;
    return [
      _encabezado(),
      const SizedBox(height: 14),
      _semana(),
      const SizedBox(height: 8),
      _cuadricula(dias),
      const SizedBox(height: 12),
      Container(height: 1, color: _borde),
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
    ];
  }

  /// "Vista Mes | Historial Completo", como un control segmentado de iOS.
  Widget _selector() {
    Widget segmento(String texto, bool historial) {
      final activo = _verHistorial == historial;
      return Expanded(
        child: Semantics(
          button: true,
          selected: activo,
          child: GestureDetector(
            onTap: () => setState(() => _verHistorial = historial),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: activo
                  ? BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  texto,
                  maxLines: 1,
                  style: TextStyle(
                    color: activo ? Colors.white : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borde),
      ),
      child: Row(
        children: [
          segmento('Vista Mes', false),
          segmento('Historial Completo', true),
        ],
      ),
    );
  }

  Widget _encabezado() {
    final periodo = widget.periodo;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_nombresDeMes[_mes.month - 1]} ${_mes.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (periodo != null && periodo.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Semestre $periodo',
                    style: const TextStyle(
                      color: _indigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _botonMes(
          Icons.chevron_left,
          'Mes anterior',
          _hayAnterior ? () => _moverMes(-1) : null,
        ),
        const SizedBox(width: 4),
        _botonMes(
          Icons.chevron_right,
          'Mes siguiente',
          _haySiguiente ? () => _moverMes(1) : null,
        ),
      ],
    );
  }

  Widget _botonMes(IconData icono, String ayuda, VoidCallback? alTocar) {
    return IconButton(
      onPressed: alTocar,
      icon: Icon(icono),
      tooltip: ayuda,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceControl,
        disabledBackgroundColor: AppTheme.surfaceControl.withValues(alpha: 0.4),
        foregroundColor: AppTheme.textSecondary,
        disabledForegroundColor: AppTheme.textTertiary,
        side: const BorderSide(color: _borde),
      ),
    );
  }

  /// L M M J V S D, con una línea debajo.
  Widget _semana() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borde)),
      ),
      child: Row(
        children: [
          for (final d in _diasCortos)
            Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cuadricula(Map<int, DiaPintado> dias) {
    final hoy = widget.hoy;
    final diasDelMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final diasDelAnterior = DateTime(_mes.year, _mes.month, 0).day;
    final antes = DateTime(_mes.year, _mes.month).weekday - 1;
    final despues = (7 - (antes + diasDelMes) % 7) % 7;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      children: [
        for (var i = antes; i > 0; i--) _diaVecino(diasDelAnterior - i + 1),
        for (var d = 1; d <= diasDelMes; d++)
          _dia(
            d,
            dias[d],
            esHoy: hoy.year == _mes.year &&
                hoy.month == _mes.month &&
                hoy.day == d,
            finDeSemana: DateTime(_mes.year, _mes.month, d).weekday >= 6,
          ),
        for (var d = 1; d <= despues; d++) _diaVecino(d),
      ],
    );
  }

  /// Un día del mes anterior o del siguiente, para completar la semana.
  Widget _diaVecino(int d) {
    return ExcludeSemantics(
      child: Center(
        child: Text(
          '$d',
          style: TextStyle(
            color: AppTheme.textTertiary.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _dia(
    int d,
    DiaPintado? dia, {
    required bool esHoy,
    required bool finDeSemana,
  }) {
    final seleccionado = _seleccionado == d;
    final estilo = dia?.estilo;
    final relleno = estilo == EstiloDia.relleno;

    final Color colorTexto;
    if (relleno) {
      colorTexto = Colors.white;
    } else if (estilo == EstiloDia.aro) {
      colorTexto = Color.lerp(dia!.color, Colors.white, 0.35)!;
    } else if (esHoy) {
      colorTexto = _indigoClaro;
    } else if (finDeSemana) {
      colorTexto = AppTheme.textTertiary;
    } else {
      colorTexto = AppTheme.textSecondary;
    }

    BoxDecoration? decoracion;
    if (relleno) {
      decoracion = BoxDecoration(
        shape: BoxShape.circle,
        color: dia!.color,
        border: seleccionado
            ? Border.all(color: Colors.white, width: 2)
            : esHoy
                ? Border.all(color: _indigo, width: 2)
                : null,
        boxShadow: [
          BoxShadow(
            color: dia.color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    } else if (estilo == EstiloDia.aro) {
      decoracion = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: seleccionado ? Colors.white : dia!.color,
          width: seleccionado ? 2 : 1.5,
        ),
      );
    } else if (esHoy) {
      decoracion = BoxDecoration(
        shape: BoxShape.circle,
        color: _indigo.withValues(alpha: 0.1),
        border: Border.all(
          color: seleccionado ? Colors.white : _indigo,
          width: seleccionado ? 2 : 1,
        ),
      );
    } else if (seleccionado) {
      decoracion = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      );
    }

    final descripcion = [
      if (esHoy) 'hoy',
      if (dia != null) dia.descripcion,
    ].join(', ');
    return Semantics(
      key: ValueKey('dia-$d'),
      button: dia != null,
      label: descripcion.isEmpty ? '$d' : '$d, $descripcion',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: dia == null
            ? null
            : () => setState(() => _seleccionado = seleccionado ? null : d),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox.square(
              dimension: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: decoracion,
                    alignment: Alignment.center,
                    child: Text(
                      '$d',
                      style: TextStyle(
                        color: colorTexto,
                        fontSize: 13,
                        fontWeight: relleno || esHoy
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (estilo == EstiloDia.punto)
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dia!.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leyenda() {
    Widget item(Color color, String texto, EstiloDia? estilo) {
      final BoxDecoration punto;
      switch (estilo) {
        case EstiloDia.relleno:
          punto = BoxDecoration(color: color, shape: BoxShape.circle);
        case EstiloDia.aro:
          punto = BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          );
        case EstiloDia.punto:
          punto = BoxDecoration(color: color, shape: BoxShape.circle);
        case null: // Hoy.
          punto = BoxDecoration(
            shape: BoxShape.circle,
            color: _indigo.withValues(alpha: 0.1),
            border: Border.all(color: _indigo),
          );
      }
      final tamano = estilo == EstiloDia.punto ? 5.0 : 10.0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 10,
            child: Center(
              child: Container(
                width: tamano,
                height: tamano,
                decoration: punto,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceAround,
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final i in widget.leyenda) item(i.color, i.texto, i.estilo),
        item(_indigo, 'Hoy', null),
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
  List<DateTime> fechasExtra = const [],
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
    final hayExtra = fechasExtra.any(
      (e) => e.year == fecha.year && e.month == fecha.month && e.day == d,
    );
    if (diasDeClase.contains(fecha.weekday) || hayExtra) {
      estados[d] = EstadoDia.proxima;
    }
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

  /// "2026-2", para el chip junto al mes.
  final String? periodo;

  /// La lista de clases dictadas, para "Historial Completo".
  final Widget? historial;

  /// Cuándo empiezan las clases extra programadas.
  final List<DateTime> fechasExtra;

  const CalendarioAsistencia({
    super.key,
    required this.clases,
    required this.diasDeClase,
    required this.hoy,
    this.semestre,
    this.periodo,
    this.historial,
    this.fechasExtra = const [],
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
        fechasExtra: fechasExtra,
      );

  Map<int, DiaPintado> _dias(DateTime mes) => _estados(mes).map(
        (d, e) => MapEntry(
          d,
          DiaPintado(
            color: _color(e),
            estilo: e == EstadoDia.proxima ? EstiloDia.punto : EstiloDia.relleno,
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
    final extra = fechasExtra.where(
      (e) =>
          e.year == fecha.year && e.month == fecha.month && e.day == fecha.day,
    );
    final lineas = delDia.isEmpty
        ? [
            if (diasDeClase.contains(fecha.weekday))
              'Clase programada según el horario.',
            for (final e in extra) 'Clase extra a las ${horaCorta(e)}.',
          ]
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
      periodo: periodo,
      historial: historial,
      leyenda: const [
        ItemLeyenda(_verde, 'Presente'),
        ItemLeyenda(_ambar, 'Tarde'),
        ItemLeyenda(_rojo, 'Falla'),
        ItemLeyenda(_azul, 'Justificada'),
        ItemLeyenda(_indigo, 'Próxima', estilo: EstiloDia.punto),
      ],
    );
  }
}
