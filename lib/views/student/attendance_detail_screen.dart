import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asistencia_resumen.dart';
import '../../models/sesion_model.dart';
import '../../models/student_subject_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/student_viewmodel.dart';
import '../../widgets/botones_accesibles.dart';
import '../../widgets/calendario_asistencia.dart';
import '../../widgets/texto_sin_cortes.dart';

/// La asistencia del estudiante en una materia: cuánto lleva, cuántas fallas
/// le quedan antes de bajar del mínimo y qué pasó en cada clase dictada.
///
/// El resumen llega con [subject] (es el mismo del portal); el detalle por
/// clase se pide aquí, porque solo hace falta al abrir esta pantalla.
class AttendanceDetailScreen extends StatefulWidget {
  final StudentSubjectModel subject;

  const AttendanceDetailScreen({super.key, required this.subject});

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  // Colores exactos del HTML de Stitch
  static const Color _primaryIndigo = Color(0xFF5E5CE6); // primary-container
  static const Color _primaryFixed = Color(0xFFE2DFFF); // primary-fixed
  static const Color _tertiaryGreen = Color(0xFF47E266); // tertiary
  static const Color _systemAmber = Color(0xFFFF9F0A);
  static const Color _systemRed = Color(0xFFFF453A);
  static const Color _azulJustificada = Color(0xFF0A84FF);

  static const _dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  late Future<List<ClaseDelEstudiante>> _historial;

  @override
  void initState() {
    super.initState();
    _historial = context.read<StudentViewModel>().historialDe(
          widget.subject.cursoId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final materia = widget.subject;
    return Scaffold(
      backgroundColor: Colors.black, // bg-surface-oled
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavigationHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                children: [
                  _buildCourseTitleSection(materia),
                  const SizedBox(height: 20),
                  // El portal leyó la asistencia al abrirse, y el docente
                  // pudo corregirla después (una falta justificada, una
                  // marca a mano). Con el historial recién leído, el
                  // termómetro dice lo mismo que el calendario de abajo.
                  FutureBuilder<List<ClaseDelEstudiante>>(
                    future: _historial,
                    builder: (context, estado) => _buildTermometro(
                      estado.hasData
                          ? AsistenciaResumen.de(estado.data!)
                              .conClasesDelSemestre(
                                materia.asistencia.clasesDelSemestre,
                              )
                          : materia.asistencia,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildCalendario(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Tocable(
            onTap: () => Navigator.pop(context),
            alineacion: AlignmentDirectional.centerStart,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left,
                  color: AppTheme.primaryTexto,
                  size: 26,
                ),
                Text(
                  'Mis materias',
                  style: TextStyle(
                    color: AppTheme.primaryTexto,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTitleSection(StudentSubjectModel materia) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: _primaryIndigo.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                materia.code,
                style: const TextStyle(
                  color: _primaryFixed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Text(
              '• Grupo ${materia.group}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          materia.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        _buildDato(Icons.person_outline, 'Docente: ', materia.professor),
        const SizedBox(height: 4),
        _buildDato(Icons.schedule, '', materia.schedule),
        if (materia.room.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildDato(Icons.meeting_room_outlined, '', materia.room),
        ],
      ],
    );
  }

  Widget _buildDato(IconData icono, String etiqueta, String valor) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.surfaceControl,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icono, color: AppTheme.textSecondary, size: 13),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              children: [
                if (etiqueta.isNotEmpty) TextSpan(text: etiqueta),
                TextSpan(
                  text: valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Cuánto lleva y cuánto le queda, con las mismas cuentas que el portal
  /// ([AsistenciaResumen]).
  Widget _buildTermometro(AsistenciaResumen r) {
    final porcentaje = r.porcentaje;
    final color = switch (r.nivel) {
      NivelAsistencia.alDia => _tertiaryGreen,
      NivelAsistencia.atencion => _systemAmber,
      NivelAsistencia.riesgo => _systemRed,
    };
    final conoce = r.conoceElSemestre;
    final String aviso;
    if (!conoce) {
      // Sin las fechas del semestre no se sabe el límite: se dice lo que hay.
      aviso = r.sesiones == 0
          ? 'Aún no hay clases'
          : r.faltas == 1
              ? 'Llevas 1 falla'
              : 'Llevas ${r.faltas} fallas';
    } else if (r.faltas > r.faltasPermitidas) {
      aviso = 'Por debajo del mínimo';
    } else if (r.faltasDisponibles == 0) {
      aviso = 'No te quedan fallas';
    } else if (r.faltasDisponibles == 1) {
      aviso = 'Te queda 1 falla';
    } else {
      aviso = 'Te quedan ${r.faltasDisponibles} fallas';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Si el título y la píldora no caben juntos, la píldora baja.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 8,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.thermostat, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Termómetro de asistencia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // Las justificadas no se le cuentan: el mínimo es
                          // sobre las demás.
                          'Mínimo para aprobar: ${AsistenciaResumen.minimo}%'
                          '${conoce ? ' de ${r.clasesContables} clases' : ''}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: color),
                    const SizedBox(width: 5),
                    Text(
                      aviso,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                porcentaje == null ? '—' : '$porcentaje%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: '${r.faltas}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: conoce
                          ? ' / ${r.faltasPermitidas} fallas permitidas'
                          : r.faltas == 1
                              ? ' falla'
                              : ' fallas',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBarra(porcentaje, color),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, caja) {
              final contadores = [
                _buildContador(
                  punto: _tertiaryGreen,
                  valor: '${r.asistidas}',
                  etiqueta: 'Asistidas',
                ),
                _buildContador(
                  punto: _systemRed,
                  valor: '${r.faltas}',
                  etiqueta: 'Fallas',
                ),
                _buildContador(
                  punto: AppTheme.textSecondary,
                  valor: conoce
                      ? '${r.sesiones}/${r.clasesContables}'
                      : '${r.sesiones}',
                  etiqueta: 'Dictadas',
                ),
                _buildContador(
                  punto: color,
                  valor: conoce ? '${r.faltasDisponibles}' : '—',
                  etiqueta: 'Restantes',
                ),
              ];
              // Los cuatro en fila si cabe la etiqueta más larga entera; si
              // no (celular angosto o letra grande), de dos en dos.
              final medida = TextPainter(
                text: TextSpan(
                  text: 'Restantes',
                  style: DefaultTextStyle.of(context).style
                      .copyWith(fontSize: 13),
                ),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final porFila = (caja.maxWidth - 18) / 4 >= medida.width + 10
                  ? 4
                  : 2;
              medida.dispose();
              return Column(
                children: [
                  for (var i = 0; i < contadores.length; i += porFila) ...[
                    if (i > 0) const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var j = i; j < i + porFila; j++) ...[
                          if (j > i) const SizedBox(width: 6),
                          Expanded(child: contadores[j]),
                        ],
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// La asistencia sobre una barra de 0 a 100, con una marca en el mínimo.
  Widget _buildBarra(int? porcentaje, Color color) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth;
        return SizedBox(
          height: 12,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F21),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              if (porcentaje != null && porcentaje > 0)
                Container(
                  width: ancho * porcentaje / 100,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              Positioned(
                left: ancho * AsistenciaResumen.minimo / 100 - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContador({
    required Color punto,
    required String valor,
    required String etiqueta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceControl.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 4, backgroundColor: punto),
              const SizedBox(width: 5),
              // "12/33" no cabe entero en un celular angosto: se encoge.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    valor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextoSinCortes(
            etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// El mes a mes de la materia con los mismos datos de "Clases dictadas".
  /// El calendario de la materia; "Historial Completo" muestra cada clase
  /// dictada con lo que pasó, con los mismos datos.
  Widget _buildCalendario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'CALENDARIO DE ASISTENCIA',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<ClaseDelEstudiante>>(
          future: _historial,
          builder: (context, estado) {
            if (estado.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // Si falla, el calendario se muestra igual con el horario y el
            // aviso sale en el historial.
            return CalendarioAsistencia(
              clases: estado.data ?? const [],
              diasDeClase: widget.subject.diasDeClase,
              semestre: widget.subject.semestre,
              periodo: widget.subject.periodo,
              fechasExtra: widget.subject.fechasExtra,
              hoy: DateTime.now(),
              historial: _buildHistorial(estado),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistorial(AsyncSnapshot<List<ClaseDelEstudiante>> estado) {
    if (estado.hasError) {
      return _buildMensaje(
        'No se pudo cargar tu historial. Revisa tu conexión y vuelve a abrir '
        'la materia.',
      );
    }
    final clases = estado.data ?? const [];
    if (clases.isEmpty) {
      return _buildMensaje('Todavía no termina ninguna clase de esta materia.');
    }
    return Column(
      children: [
        for (final clase in clases)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildClase(clase),
          ),
      ],
    );
  }

  Widget _buildMensaje(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Text(
        texto,
        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 14),
      ),
    );
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  String _fecha(DateTime d) =>
      '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

  Widget _buildClase(ClaseDelEstudiante clase) {
    final marca = clase.marca;
    final asistio = clase.asistio;
    final justificada = clase.justificada;
    final porRadar = asistio && marca!.metodo == MetodoAsistencia.ble;
    final color = asistio
        ? _tertiaryGreen
        : justificada
            ? _azulJustificada
            : _systemRed;
    final String detalle;
    if (justificada) {
      detalle = 'Falta justificada por el docente: no se cuenta';
    } else if (!asistio) {
      detalle = marca == null ? 'Sin marca' : 'Marcado ausente por el docente';
    } else {
      final hora = _hora(marca!.hora);
      detalle = porRadar ? 'Por Bluetooth • $hora' : 'Marcado a mano • $hora';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              asistio
                  ? Icons.check
                  : justificada
                      ? Icons.assignment_turned_in_outlined
                      : Icons.close,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fecha(clase.franja),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            asistio
                ? 'Asistió'
                : justificada
                    ? 'Justificada'
                    : 'Faltó',
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
}
