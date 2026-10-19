import 'dart:math';

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
  final Geocerca? geocerca;
  final List<String> clavesInscritos;
  final int totalInscritos;

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
    this.geocerca,
    this.clavesInscritos = const [],
    this.totalInscritos = 0,
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
      geocerca: geocerca == null ? null : Geocerca.fromMap(geocerca),
      clavesInscritos:
          List<String>.from(map['claves_inscritos'] as List? ?? const []),
      totalInscritos: map['total_inscritos'] as int? ?? 0,
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
        'geocerca': geocerca?.toMap(),
        'claves_inscritos': clavesInscritos,
        'total_inscritos': totalInscritos,
      };

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
