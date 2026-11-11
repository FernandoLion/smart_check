import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
import '../models/calendario_academico.dart';
import '../models/curso_model.dart';
import '../utils/app_theme.dart';
import '../viewmodels/course_detail_viewmodel.dart';
import 'calendario_asistencia.dart';

/// Qué pasó un día con la clase de un curso, visto por el docente.
enum EstadoClaseCurso {
  /// Se dictó y vino el 90 % o más del grupo.
  alta,

  /// Se dictó y vino del 80 % al 89 %.
  media,

  /// Se dictó y vino menos del 80 %, el mínimo de la universidad.
  baja,

  /// Tocaba clase según el horario y no se abrió el radar.
  sinLlamado,

  /// Hoy o más adelante toca clase.
  proxima,
}

/// Un día del calendario del curso.
class DiaDelCurso {
  final EstadoClaseCurso estado;

  /// Las clases dictadas ese día; vacío si no se dictó ninguna.
  final List<SesionResumen> clases;

  /// Los bloques del horario de ese día.
  final List<Horario> bloques;

  const DiaDelCurso(this.estado, {this.clases = const [], this.bloques = const []});

  /// Del grupo en todas las clases del día, o null si no había inscritos.
  int? get porcentaje => _porcentajeDe(clases);
}

int? _porcentajeDe(Iterable<SesionResumen> clases) {
  final inscritos = clases.fold(0, (n, c) => n + c.inscritos);
  if (inscritos == 0) return null;
  final asistieron = clases.fold(0, (n, c) => n + c.asistieron);
  return (asistieron * 100 / inscritos).round();
}

DateTime _conMinutos(DateTime dia, int minutos) =>
    DateTime(dia.year, dia.month, dia.day, minutos ~/ 60, minutos % 60);

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Cada día de [mes] que tuvo o tendrá clase, por número de día.
///
/// Un día del horario cuenta como "sin llamado" solo si su bloque ya terminó
/// y terminó después de crear el curso: antes de eso no existía. Sin fecha de
/// creación se toma la primera clase dictada. Fuera de las fechas del
/// [semestre] no se espera ninguna clase, y de un curso archivado tampoco
/// después de la última.
Map<int, DiaDelCurso> diasDelCurso({
  required DateTime mes,
  required List<SesionResumen> sesiones,
  required List<Horario> horarios,
  required DateTime ahora,
  DateTime? creadoEn,
  Semestre? semestre,
  bool archivado = false,
}) {
  final franjas = sesiones.map((s) => s.sesion.franja).toList()..sort();
  final desde = creadoEn ?? (franjas.isEmpty ? null : franjas.first);
  final tope = archivado ? (franjas.isEmpty ? desde : franjas.last) : null;

  final dias = <int, DiaDelCurso>{};
  final ultimo = DateTime(mes.year, mes.month + 1, 0).day;
  for (var d = 1; d <= ultimo; d++) {
    final fecha = DateTime(mes.year, mes.month, d);
    final bloques = horarios.where((h) => h.dia == fecha.weekday).toList();
    final clases =
        sesiones.where((s) => _mismoDia(s.sesion.franja, fecha)).toList();

    if (clases.isNotEmpty) {
      final nivel = AsistenciaResumen.nivelDe(_porcentajeDe(clases));
      dias[d] = DiaDelCurso(
        switch (nivel) {
          NivelAsistencia.alDia => EstadoClaseCurso.alta,
          NivelAsistencia.atencion => EstadoClaseCurso.media,
          NivelAsistencia.riesgo => EstadoClaseCurso.baja,
        },
        clases: clases,
        bloques: bloques,
      );
      continue;
    }
    if (bloques.isEmpty) continue;
    if (semestre != null && !semestre.contiene(fecha)) continue;

    final fines = bloques.map((b) => _conMinutos(fecha, b.finMinutos));
    final queda = fines.any((fin) => fin.isAfter(ahora));
    final faltaron = fines.where(
      (fin) =>
          !fin.isAfter(ahora) &&
          desde != null &&
          fin.isAfter(desde) &&
          (tope == null || !fin.isAfter(_finDelDia(tope))),
    );
    if (faltaron.isNotEmpty) {
      dias[d] = DiaDelCurso(EstadoClaseCurso.sinLlamado, bloques: bloques);
    } else if (queda && !archivado) {
      dias[d] = DiaDelCurso(EstadoClaseCurso.proxima, bloques: bloques);
    }
  }
  return dias;
}

DateTime _finDelDia(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59);

/// El calendario del curso: el % del grupo en cada clase dictada y los días
/// que tocaba clase y no se abrió el radar. Al tocar una clase se abre su
/// detalle, donde se corrigen las asistencias.
class CalendarioDelCurso extends StatelessWidget {
  static const _verde = Color(0xFF30D158);
  static const _ambar = Color(0xFFFF9F0A);
  static const _rojo = Color(0xFFFF453A);
  static const _gris = Color(0xFF8E8E93);
  static const _indigo = Color(0xFF5E5CE6);

  /// Las clases dictadas (las de [CourseDetailViewModel.sesionesPasadas]).
  final List<SesionResumen> sesiones;
  final List<Horario> horarios;
  final DateTime ahora;
  final DateTime? creadoEn;
  final Semestre? semestre;
  final bool archivado;
  final void Function(SesionResumen) alAbrirClase;

  const CalendarioDelCurso({
    super.key,
    required this.sesiones,
    required this.horarios,
    required this.ahora,
    required this.alAbrirClase,
    this.creadoEn,
    this.semestre,
    this.archivado = false,
  });

  List<DateTime> get _franjas =>
      sesiones.map((s) => s.sesion.franja).toList()..sort();

  DateTime get _primerMes {
    final franjas = _franjas;
    final candidatos = [?creadoEn, if (franjas.isNotEmpty) franjas.first];
    if (candidatos.isEmpty) return DateTime(ahora.year, ahora.month);
    final primero = candidatos.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(primero.year, primero.month);
  }

  DateTime get _ultimoMes {
    final franjas = _franjas;
    if (archivado && franjas.isNotEmpty) {
      return DateTime(franjas.last.year, franjas.last.month);
    }
    return ultimoMesDelCalendario(ahora, semestre);
  }

  Map<int, DiaDelCurso> _dias(DateTime mes) => diasDelCurso(
        mes: mes,
        sesiones: sesiones,
        horarios: horarios,
        ahora: ahora,
        creadoEn: creadoEn,
        semestre: semestre,
        archivado: archivado,
      );

  static Color _color(EstadoClaseCurso e) => switch (e) {
        EstadoClaseCurso.alta => _verde,
        EstadoClaseCurso.media => _ambar,
        EstadoClaseCurso.baja => _rojo,
        EstadoClaseCurso.sinLlamado => _gris,
        EstadoClaseCurso.proxima => _indigo,
      };

  static DiaPintado _pintar(DiaDelCurso dia) {
    final p = dia.porcentaje;
    return DiaPintado(
      color: _color(dia.estado),
      relleno: dia.estado != EstadoClaseCurso.proxima &&
          dia.estado != EstadoClaseCurso.sinLlamado,
      nota: switch (dia.estado) {
        EstadoClaseCurso.sinLlamado => '—',
        EstadoClaseCurso.proxima => null,
        _ => p == null ? null : '$p%',
      },
      descripcion: switch (dia.estado) {
        EstadoClaseCurso.sinLlamado => 'sin llamado',
        EstadoClaseCurso.proxima => 'próxima clase',
        _ => p == null ? 'clase dictada' : 'clase con $p por ciento',
      },
    );
  }

  String _resumen(DateTime mes) {
    final nombre = nombreDelMes(mes);
    final delMes = sesiones.where(
      (s) =>
          s.sesion.franja.year == mes.year &&
          s.sesion.franja.month == mes.month,
    );
    final sinLlamado = _dias(mes)
        .values
        .where((d) => d.estado == EstadoClaseCurso.sinLlamado)
        .length;
    final faltas = sinLlamado == 0
        ? ''
        : sinLlamado == 1
            ? ', 1 día sin llamado'
            : ', $sinLlamado días sin llamado';
    if (delMes.isEmpty) {
      return 'En $nombre no hay clases dictadas$faltas.';
    }
    final clases =
        delMes.length == 1 ? '1 clase dictada' : '${delMes.length} clases dictadas';
    final p = _porcentajeDe(delMes);
    return 'En $nombre: $clases'
        '${p == null ? '' : ', $p% de asistencia'}$faltas.';
  }

  String _bloque(DateTime fecha, Horario h) =>
      '${horaCorta(_conMinutos(fecha, h.inicioMinutos))} a '
      '${horaCorta(_conMinutos(fecha, h.finMinutos))}';

  Widget _detalle(DateTime fecha) {
    final dia = _dias(fecha)[fecha.day];
    final hijos = <Widget>[];
    Widget linea(String texto) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            texto,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        );
    if (dia != null && dia.clases.isNotEmpty) {
      for (final clase in dia.clases) {
        hijos.add(_filaDeClase(clase));
      }
    } else if (dia?.estado == EstadoClaseCurso.sinLlamado) {
      for (final b in dia!.bloques) {
        hijos.add(
          linea(
            'Tocaba clase de ${_bloque(fecha, b)} y no se abrió el radar.',
          ),
        );
      }
    } else if (dia != null) {
      for (final b in dia.bloques) {
        hijos.add(linea('Clase programada de ${_bloque(fecha, b)}.'));
      }
    }
    return PanelDelDia(titulo: tituloDelDia(fecha), hijos: hijos);
  }

  Widget _filaDeClase(SesionResumen clase) {
    final p = clase.porcentaje;
    return InkWell(
      onTap: () => alAbrirClase(clase),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Clase de las ${horaCorta(clase.sesion.franja)}: '
                '${clase.asistieron} de ${clase.inscritos}'
                '${p == null ? '' : ' ($p%)'}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ver',
              style: TextStyle(color: Color(0xFFC2C1FF), fontSize: 13),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFC2C1FF),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CalendarioMensual(
      hoy: ahora,
      primerMes: _primerMes,
      ultimoMes: _ultimoMes,
      cuadrado: true,
      diasDe: (mes) => _dias(mes).map((d, e) => MapEntry(d, _pintar(e))),
      resumenDe: _resumen,
      detalleDe: _detalle,
      leyenda: const [
        ItemLeyenda(_verde, '90% o más'),
        ItemLeyenda(_ambar, '80 a 89%'),
        ItemLeyenda(_rojo, 'Menos de 80%'),
        ItemLeyenda(_gris, 'Sin llamado', relleno: false),
        ItemLeyenda(_indigo, 'Próxima clase', relleno: false),
      ],
    );
  }
}
