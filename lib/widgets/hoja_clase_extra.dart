import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../utils/app_theme.dart';
import 'elegir_hora.dart';

/// Hoja para programar una clase extra: el día (de hoy al fin del semestre),
/// la hora de inicio y de fin, y el aula si cambia. Devuelve la [ClaseExtra]
/// con `Navigator.pop`, o null si se cancela.
///
/// El día se elige de una fila de fechas en español en vez del selector de
/// Flutter, que sin las traducciones del SDK sale en inglés.
class HojaClaseExtra extends StatefulWidget {
  final Curso curso;
  final DateTime ahora;

  const HojaClaseExtra({super.key, required this.curso, required this.ahora});

  @override
  State<HojaClaseExtra> createState() => _HojaClaseExtraState();
}

class _HojaClaseExtraState extends State<HojaClaseExtra> {
  static const _indigo = Color(0xFF5E5CE6);
  static const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _mesesCortos = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Se propone empezar una hora después y a más tardar a las 20:00; pasadas
  /// las 19:00 eso ya quedó atrás, así que se propone mañana a las 08:00
  /// (si mañana aún es del semestre).
  late final bool _proponerManana =
      widget.ahora.hour + 1 > 20 && _dias.length > 1;
  late DateTime _dia = _proponerManana ? _dias[1] : _hoy;
  late TimeOfDay _inicio = TimeOfDay(
    hour: _proponerManana ? 8 : (widget.ahora.hour + 1).clamp(6, 20),
    minute: 0,
  );
  late TimeOfDay _fin = TimeOfDay(hour: _inicio.hour + 2, minute: 0);
  late final _aula = TextEditingController(text: widget.curso.aula);
  String? _error;

  DateTime get _hoy =>
      DateTime(widget.ahora.year, widget.ahora.month, widget.ahora.day);

  /// De hoy al último día de clases del semestre (o dos meses si no se
  /// conocen las fechas).
  List<DateTime> get _dias {
    final hoy = _hoy;
    final fin = widget.curso.semestre?.fin ?? hoy.add(const Duration(days: 60));
    final dias = <DateTime>[];
    for (var i = 0; i < 400; i++) {
      final dia = DateTime(hoy.year, hoy.month, hoy.day + i);
      if (dia.isAfter(fin) && dias.isNotEmpty) break;
      dias.add(dia);
    }
    return dias;
  }

  static String _etiquetaDia(DateTime d) =>
      '${_diasCortos[d.weekday - 1]} ${d.day} ${_mesesCortos[d.month - 1]}';

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _hhmmDe(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _aula.dispose();
    super.dispose();
  }

  Future<void> _elegirHora(bool esInicio) async {
    final elegida = await elegirHora(
      context,
      inicial: esInicio ? _inicio : _fin,
      esInicio: esInicio,
    );
    if (elegida == null) return;
    setState(() {
      _error = null;
      if (esInicio) {
        _inicio = elegida;
      } else {
        _fin = elegida;
      }
    });
  }

  /// La clase pedida, o el motivo por el que no se puede.
  (ClaseExtra?, String?) _validar() {
    DateTime conHora(TimeOfDay t) =>
        DateTime(_dia.year, _dia.month, _dia.day, t.hour, t.minute);
    final inicio = conHora(_inicio);
    final fin = conHora(_fin);
    if (!fin.isAfter(inicio)) {
      return (null, 'La hora de fin debe ser después de la de inicio.');
    }
    if (!inicio.isAfter(widget.ahora)) {
      return (null, 'Esa hora ya pasó. Elige una más tarde.');
    }
    for (final f in widget.curso.franjasDe(_dia)) {
      if (!f.seCruzaCon(inicio, fin)) continue;
      return (
        null,
        f.esExtra
            ? 'Se cruza con otra clase extra de ese día '
                '(${_hhmmDe(f.inicio)} a ${_hhmmDe(f.fin)}).'
            : 'Se cruza con el horario de la clase '
                '(${_hhmmDe(f.inicio)} a ${_hhmmDe(f.fin)}).',
      );
    }
    return (
      ClaseExtra(
        id: '${inicio.millisecondsSinceEpoch}',
        inicio: inicio,
        fin: fin,
        aula: _aula.text.trim(),
      ),
      null,
    );
  }

  void _programar() {
    final (clase, error) = _validar();
    if (clase == null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, clase);
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Programar clase extra',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Una clase fuera del horario, como una reposición. Cuenta como '
              'una más: suma al total del semestre y quien no venga tiene '
              'falla. Ese día el radar se abre en esa franja.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('DÍA'),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final dia = dias[i];
                  return ChoiceChip(
                    label: Text(_etiquetaDia(dia)),
                    selected: dia == _dia,
                    onSelected: (_) => setState(() {
                      _dia = dia;
                      _error = null;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('HORA'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegirHora(true),
                    child: Text('Inicio ${_hhmm(_inicio)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _elegirHora(false),
                    child: Text('Fin ${_hhmm(_fin)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Etiqueta('AULA'),
            const SizedBox(height: 8),
            TextField(
              controller: _aula,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'La de siempre',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.surfaceControl,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _programar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Programar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );
}
