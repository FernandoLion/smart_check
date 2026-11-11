/// Las fechas de clase de un semestre, iguales para toda la universidad.
class Semestre {
  final DateTime inicio;

  /// El último día de clases, incluido.
  final DateTime fin;

  const Semestre(this.inicio, this.fin);

  bool contiene(DateTime momento) {
    final dia = DateTime(momento.year, momento.month, momento.day);
    return !dia.isBefore(inicio) && !dia.isAfter(fin);
  }

  /// Cuántas clases hay en el semestre con un bloque semanal por cada
  /// elemento de [dias] (1 = lunes ... 7 = domingo). Los festivos cuentan,
  /// porque la app no los conoce.
  int clasesSegun(Iterable<int> dias) {
    var clases = 0;
    final total = DateTime.utc(fin.year, fin.month, fin.day)
        .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
        .inDays;
    for (var i = 0; i <= total; i++) {
      final fecha = DateTime(inicio.year, inicio.month, inicio.day + i);
      clases += dias.where((d) => d == fecha.weekday).length;
    }
    return clases;
  }
}

/// El calendario académico de la universidad, por periodo.
///
/// **Hay que agregar aquí cada semestre nuevo.** Un periodo sin fechas no
/// rompe nada: la app no conoce el total de clases y deja de mostrar las
/// fallas que quedan, en vez de inventarlas.
class CalendarioAcademico {
  static final _semestres = {
    '2026-2': Semestre(DateTime(2026, 8, 18), DateTime(2026, 12, 4)),
  };

  /// Las fechas de [periodo] ("2026-2"), o null si no están registradas.
  static Semestre? de(String periodo) => _semestres[periodo];
}
