import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendario_academico.dart';

/// Una clase fuera del horario semanal, en una fecha concreta: una
/// reposición, una clase adicional. Cuenta como una clase más: suma al total
/// del semestre y quien no venga tiene falla.
class ClaseExtra {
  final String id;
  final DateTime inicio;
  final DateTime fin;

  /// Dónde será, si no es el aula de siempre. Solo informativo: la geocerca
  /// es la del curso.
  final String aula;

  const ClaseExtra({
    required this.id,
    required this.inicio,
    required this.fin,
    this.aula = '',
  });

  factory ClaseExtra.fromMap(Map<String, dynamic> map) => ClaseExtra(
        id: map['id'] as String? ?? '',
        inicio: (map['inicio'] as Timestamp).toDate(),
        fin: (map['fin'] as Timestamp).toDate(),
        aula: map['aula'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'aula': aula,
      };
}

/// Un bloque de clase con fecha: de un día del horario semanal o una clase
/// extra. Es lo que abre el radar y lo que agrupa los llamados.
class Franja {
  final DateTime inicio;
  final DateTime fin;

  /// La clase extra de la que sale, o null si es del horario semanal.
  final ClaseExtra? extra;

  const Franja(this.inicio, this.fin, {this.extra});

  bool get esExtra => extra != null;

  bool contiene(DateTime momento) =>
      !momento.isBefore(inicio) && momento.isBefore(fin);

  bool seCruzaCon(DateTime desde, DateTime hasta) =>
      desde.isBefore(fin) && hasta.isAfter(inicio);
}

/// Las clases de [dia]: los bloques del horario de ese día de la semana y
/// las clases extra de esa fecha, en orden.
List<Franja> franjasDelDia(
  List<Horario> horarios,
  List<ClaseExtra> extras,
  DateTime dia,
) {
  DateTime conMinutos(int m) =>
      DateTime(dia.year, dia.month, dia.day, m ~/ 60, m % 60);
  return [
    for (final h in horarios)
      if (h.dia == dia.weekday)
        Franja(conMinutos(h.inicioMinutos), conMinutos(h.finMinutos)),
    for (final e in extras)
      if (e.inicio.year == dia.year &&
          e.inicio.month == dia.month &&
          e.inicio.day == dia.day)
        Franja(e.inicio, e.fin, extra: e),
  ]..sort((a, b) => a.inicio.compareTo(b.inicio));
}

/// Un bloque semanal de clase: día (1 = lunes ... 7 = domingo, como
/// [DateTime.weekday]) y horas de inicio y fin en formato "HH:mm".
class Horario {
  final int dia;
  final String inicio;
  final String fin;

  const Horario({required this.dia, required this.inicio, required this.fin});

  factory Horario.fromMap(Map<String, dynamic> map) => Horario(
        dia: map['dia'] as int? ?? 1,
        inicio: map['inicio'] as String? ?? '00:00',
        fin: map['fin'] as String? ?? '00:00',
      );

  Map<String, dynamic> toMap() => {'dia': dia, 'inicio': inicio, 'fin': fin};

  int get inicioMinutos => _minutos(inicio);
  int get finMinutos => _minutos(fin);

  /// Si [momento] cae dentro de este bloque (mismo día de la semana y hora).
  bool contiene(DateTime momento) {
    if (momento.weekday != dia) return false;
    final m = momento.hour * 60 + momento.minute;
    return m >= inicioMinutos && m < finMinutos;
  }

  static int _minutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }
}

/// Zona circular donde debe estar el estudiante para que cuente su asistencia.
class Geocerca {
  final double latitud;
  final double longitud;
  final double radioMetros;

  const Geocerca({
    required this.latitud,
    required this.longitud,
    required this.radioMetros,
  });

  factory Geocerca.fromMap(Map<String, dynamic> map) => Geocerca(
        latitud: (map['latitud'] as num).toDouble(),
        longitud: (map['longitud'] as num).toDouble(),
        radioMetros: (map['radio_metros'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'latitud': latitud,
        'longitud': longitud,
        'radio_metros': radioMetros,
      };

  /// Distancia en metros desde el centro (fórmula del haversine).
  double distanciaA(double lat, double lng) {
    const radioTierra = 6371000.0;
    double rad(double g) => g * pi / 180;
    final dLat = rad(lat - latitud);
    final dLng = rad(lng - longitud);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(latitud)) * cos(rad(lat)) * sin(dLng / 2) * sin(dLng / 2);
    return radioTierra * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  bool contiene(double lat, double lng) => distanciaA(lat, lng) <= radioMetros;
}

/// Modelo (M de MVVM) de un curso creado por un docente.
///
/// Se guarda en Firestore en `cursos/{id}`. [clavesInscritos] repite la
/// cédula y/o el correo de cada inscrito para que el estudiante encuentre sus
/// cursos con una sola consulta, aunque se haya registrado después.
class Curso {
  final String id;
  final String codigo;
  final String nombre;
  final String grupo;
  final String aula;
  final String periodo;
  final String docenteUid;
  final String docenteNombre;
  final List<Horario> horarios;

  /// Las clases fuera del horario semanal (ver [ClaseExtra]).
  final List<ClaseExtra> clasesExtra;
  final Geocerca? geocerca;
  final List<String> clavesInscritos;
  final int totalInscritos;

  /// Curso de un periodo que ya pasó: sale de la lista principal del docente
  /// y su radar no se ofrece, pero conserva inscritos y asistencias.
  final bool archivado;

  /// Cuándo se creó. Las clases del horario de antes de esta fecha no se le
  /// pueden reclamar al docente. Null en un curso que aún no se ha guardado.
  final DateTime? creadoEn;

  const Curso({
    this.id = '',
    required this.codigo,
    required this.nombre,
    required this.grupo,
    required this.aula,
    required this.periodo,
    required this.docenteUid,
    required this.docenteNombre,
    this.horarios = const [],
    this.clasesExtra = const [],
    this.geocerca,
    this.clavesInscritos = const [],
    this.totalInscritos = 0,
    this.archivado = false,
    this.creadoEn,
  });

  factory Curso.fromMap(String id, Map<String, dynamic> map) {
    final geocerca = map['geocerca'] as Map<String, dynamic>?;
    return Curso(
      id: id,
      codigo: map['codigo'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      grupo: map['grupo'] as String? ?? '',
      aula: map['aula'] as String? ?? '',
      periodo: map['periodo'] as String? ?? '',
      docenteUid: map['docente_uid'] as String? ?? '',
      docenteNombre: map['docente_nombre'] as String? ?? '',
      horarios: (map['horarios'] as List? ?? const [])
          .map((h) => Horario.fromMap(Map<String, dynamic>.from(h as Map)))
          .toList(),
      clasesExtra: (map['clases_extra'] as List? ?? const [])
          .map((e) => ClaseExtra.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      geocerca: geocerca == null ? null : Geocerca.fromMap(geocerca),
      clavesInscritos:
          List<String>.from(map['claves_inscritos'] as List? ?? const []),
      totalInscritos: map['total_inscritos'] as int? ?? 0,
      archivado: map['archivado'] as bool? ?? false,
      creadoEn: (map['creado_en'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'grupo': grupo,
        'aula': aula,
        'periodo': periodo,
        'docente_uid': docenteUid,
        'docente_nombre': docenteNombre,
        'horarios': horarios.map((h) => h.toMap()).toList(),
        'clases_extra': clasesExtra.map((e) => e.toMap()).toList(),
        'geocerca': geocerca?.toMap(),
        'claves_inscritos': clavesInscritos,
        'total_inscritos': totalInscritos,
        'archivado': archivado,
        // Va para que rearmar el curso en memoria no la pierda. Al crearlo,
        // el servicio pone la hora del servidor encima.
        if (creadoEn != null) 'creado_en': Timestamp.fromDate(creadoEn!),
      };

  /// Las fechas del semestre de este curso, si están en el calendario.
  Semestre? get semestre => CalendarioAcademico.de(periodo);

  /// Las clases que tendrá en todo el semestre (las del horario semanal y
  /// las extra que caen en él), o null si no se sabe.
  int? get clasesDelSemestre {
    final fechas = semestre;
    if (fechas == null || (horarios.isEmpty && clasesExtra.isEmpty)) {
      return null;
    }
    return fechas.clasesSegun(horarios.map((h) => h.dia)) +
        clasesExtra.where((e) => fechas.contiene(e.inicio)).length;
  }

  /// Las clases de [dia], del horario semanal y extra.
  List<Franja> franjasDe(DateTime dia) =>
      franjasDelDia(horarios, clasesExtra, dia);

  /// La clase que está ocurriendo en [momento], del horario o extra.
  Franja? franjaEn(DateTime momento) {
    for (final f in franjasDe(momento)) {
      if (f.contiene(momento)) return f;
    }
    return null;
  }

  /// Periodo académico de [momento]: "2026-1" (ene-jun) o "2026-2" (jul-dic).
  static String periodoActual([DateTime? momento]) {
    final m = momento ?? DateTime.now();
    return '${m.year}-${m.month <= 6 ? 1 : 2}';
  }

  /// El bloque de horario que está en curso en [momento], o null.
  Horario? horarioEn(DateTime momento) {
    for (final h in horarios) {
      if (h.contiene(momento)) return h;
    }
    return null;
  }
}
