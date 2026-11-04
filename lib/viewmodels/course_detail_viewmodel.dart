import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
import '../models/inscrito_model.dart';
import '../models/sesion_model.dart';
import '../services/curso_service.dart';

/// Un inscrito con su asistencia al curso, para la lista del docente.
class InscritoAsistencia {
  final Inscrito inscrito;
  final AsistenciaResumen asistencia;

  const InscritoAsistencia(this.inscrito, this.asistencia);

  String get nombre => inscrito.nombre;

  /// Lo que identifica al estudiante en la lista: su cédula o su correo.
  String get identificacion => inscrito.cedula ?? inscrito.email ?? '';
}

/// Un inscrito en una clase pasada: si quedó presente y con qué marca.
class FilaDeSesion {
  final Inscrito inscrito;

  /// La marca que decide su estado en esa clase, o null si nadie lo marcó.
  /// Si asistió, la primera que cuenta; si no, la última que lo dejó
  /// ausente (una corrección a mano).
  final Asistencia? marca;

  const FilaDeSesion(this.inscrito, this.marca);

  bool get presente => marca?.cuentaComoAsistio ?? false;
}

/// Una sesión con cuántos inscritos asistieron.
class SesionResumen {
  final Sesion sesion;
  final int asistieron;
  final int inscritos;

  const SesionResumen(this.sesion, this.asistieron, this.inscritos);

  int? get porcentaje =>
      inscritos == 0 ? null : (asistieron * 100 / inscritos).round();

  bool get bajaAsistencia {
    final p = porcentaje;
    return p != null && p < AsistenciaResumen.minimo;
  }
}

/// ViewModel del detalle de un curso: sus sesiones y sus inscritos con la
/// asistencia de cada uno.
class CourseDetailViewModel extends ChangeNotifier {
  final CursoService _servicio;

  /// Inyectable para poder probar qué cuenta como clase pasada sin depender
  /// de la hora a la que se corran los tests.
  final DateTime Function() _ahora;

  CourseDetailViewModel({CursoService? servicio, DateTime Function()? reloj})
      : _servicio = servicio ?? CursoService(),
        _ahora = reloj ?? DateTime.now;

  StreamSubscription<List<Inscrito>>? _subInscritos;
  StreamSubscription<List<Sesion>>? _subSesiones;
  String? _cursoId;

  List<Inscrito> _inscritos = const [];
  List<Sesion> _sesiones = const [];
  Map<String, List<Asistencia>> _asistencias = const {};
  bool _cargando = false;
  String? _error;

  /// Una lectura puede terminar después de cerrar la pantalla: entonces ya
  /// no hay a quién avisar.
  bool _desechado = false;

  bool get cargando => _cargando;
  String? get error => _error;
  int get totalInscritos => _inscritos.length;

  /// Las sesiones de la más reciente a la más antigua.
  List<Sesion> get sesiones => _sesiones;

  /// El llamado que sigue vigente, si hay alguno. Uno marcado como abierto
  /// cuya ventana ya pasó es una clase pasada, no una clase en curso: pasa
  /// cuando al docente se le muere la app sin cerrar el radar.
  Sesion? get llamadoVigente {
    final ahora = _ahora();
    for (final s in _sesiones) {
      if (s.abierta && !s.vencida(ahora)) return s;
    }
    return null;
  }

  /// Una fila por franja de clase, no por llamado: el docente pudo abrir el
  /// radar dos veces en el mismo bloque y eso sigue siendo una sola clase,
  /// igual que en el porcentaje que ve el estudiante.
  List<SesionResumen> get sesionesPasadas {
    final filas = CursoService.franjasTerminadas(_sesiones, _ahora())
        .values
        .map(
          (sesiones) => SesionResumen(
            sesiones.first,
            _asistieronEnLaFranja(sesiones).length,
            _inscritos.length,
          ),
        )
        .toList();
    filas.sort((a, b) => b.sesion.franja.compareTo(a.sesion.franja));
    return filas;
  }

  /// Quiénes quedaron marcados en alguno de los llamados de una franja.
  Set<String> _asistieronEnLaFranja(List<Sesion> sesiones) => {
        for (final sesion in sesiones)
          for (final a in _asistencias[sesion.id] ?? const <Asistencia>[])
            if (a.cuentaComoAsistio) a.claveInscrito,
      };

  /// Quién vino a la clase de [franja] y cómo quedó marcado: los presentes
  /// primero, por hora de llegada, y luego los ausentes por nombre.
  List<FilaDeSesion> detalleDeFranja(DateTime franja) {
    final sesiones = CursoService.franjasTerminadas(_sesiones, _ahora())[franja] ??
        const <Sesion>[];
    final marcas = [
      for (final s in sesiones) ...?_asistencias[s.id],
    ];
    final filas = [
      for (final i in _inscritos) FilaDeSesion(i, _marcaDe(i.clave, marcas)),
    ];
    filas.sort((a, b) {
      if (a.presente != b.presente) return a.presente ? -1 : 1;
      if (a.presente) return a.marca!.hora.compareTo(b.marca!.hora);
      return a.inscrito.nombre.compareTo(b.inscrito.nombre);
    });
    return filas;
  }

  /// Cuántas veces abrió el docente el radar en la clase de [franja].
  int llamadosDeFranja(DateTime franja) =>
      CursoService.franjasTerminadas(_sesiones, _ahora())[franja]?.length ?? 0;

  static Asistencia? _marcaDe(String clave, List<Asistencia> marcas) {
    final suyas = marcas.where((a) => a.claveInscrito == clave).toList()
      ..sort((a, b) => a.hora.compareTo(b.hora));
    if (suyas.isEmpty) return null;
    for (final a in suyas) {
      if (a.cuentaComoAsistio) return a;
    }
    return suyas.last;
  }

  /// Corrige a mano la asistencia de [inscrito] en la clase de [franja].
  ///
  /// Para darlo por presente basta una marca en el primer llamado de la
  /// franja. Para darlo por ausente hay que corregir cada llamado donde
  /// quedó presente, porque con uno solo ya contaría como asistido. Las
  /// reglas aceptan correcciones manuales también después de cerrado el
  /// llamado. Devuelve el error para mostrarlo, o null si se guardó.
  Future<String?> corregirAsistencia(
    DateTime franja,
    Inscrito inscrito, {
    required bool presente,
    required String docenteUid,
  }) async {
    final cursoId = _cursoId;
    final sesiones =
        CursoService.franjasTerminadas(_sesiones, _ahora())[franja];
    if (cursoId == null || sesiones == null || sesiones.isEmpty) {
      return 'Esa clase ya no está en la lista.';
    }
    final aCorregir = presente
        ? [sesiones.reduce((a, b) => a.inicio.isBefore(b.inicio) ? a : b)]
        : [
            for (final s in sesiones)
              if ((_asistencias[s.id] ?? const <Asistencia>[]).any(
                (a) => a.claveInscrito == inscrito.clave && a.cuentaComoAsistio,
              ))
                s,
          ];
    final nuevas = Map<String, List<Asistencia>>.from(_asistencias);
    try {
      for (final sesion in aCorregir) {
        final marca = Asistencia(
          claveInscrito: inscrito.clave,
          estado: presente
              ? EstadoAsistencia.presente
              : EstadoAsistencia.ausente,
          metodo: MetodoAsistencia.manual,
          hora: _ahora(),
          registradoPor: docenteUid,
        );
        await _servicio.registrarAsistencia(cursoId, sesion.id, marca);
        nuevas[sesion.id] = [
          for (final a in nuevas[sesion.id] ?? const <Asistencia>[])
            if (a.claveInscrito != inscrito.clave) a,
          marca,
        ];
      }
    } on CursoException catch (e) {
      return e.mensaje;
    } finally {
      // Lo que alcanzó a guardarse se ve ya, sin esperar a que cambien las
      // sesiones: el panel no se queda con la foto de antes.
      if (!_desechado && _cursoId == cursoId) {
        _asistencias = nuevas;
        notifyListeners();
      }
    }
    return null;
  }

  /// Los inscritos con su asistencia, los de mayor riesgo primero.
  List<InscritoAsistencia> get inscritos {
    final franjas = CursoService.franjasTerminadas(_sesiones, _ahora());
    final asistidasPor = <String, int>{};
    for (final sesiones in franjas.values) {
      for (final clave in _asistieronEnLaFranja(sesiones)) {
        asistidasPor[clave] = (asistidasPor[clave] ?? 0) + 1;
      }
    }
    final lista = _inscritos
        .map(
          (i) => InscritoAsistencia(
            i,
            AsistenciaResumen(
              sesiones: franjas.length,
              asistidas: asistidasPor[i.clave] ?? 0,
            ),
          ),
        )
        .toList();
    lista.sort((a, b) {
      final porA = a.asistencia.porcentaje ?? 100;
      final porB = b.asistencia.porcentaje ?? 100;
      if (porA != porB) return porA.compareTo(porB);
      return a.nombre.compareTo(b.nombre);
    });
    return lista;
  }

  int get enRiesgo => inscritos
      .where((i) => i.asistencia.nivel == NivelAsistencia.riesgo)
      .length;

  /// Asistencia media del curso sobre todas las clases que ya pasaron.
  AsistenciaResumen get promedio {
    final todos = inscritos;
    return AsistenciaResumen(
      sesiones: todos.fold(0, (t, i) => t + i.asistencia.sesiones),
      asistidas: todos.fold(0, (t, i) => t + i.asistencia.asistidas),
    );
  }

  /// Empieza a escuchar los inscritos y las sesiones de [cursoId]. Llamarlo
  /// otra vez con el mismo id no hace nada.
  void vigilar(String cursoId) {
    if (_cursoId == cursoId) return;
    _subInscritos?.cancel();
    _subSesiones?.cancel();
    _cursoId = cursoId;
    _inscritos = const [];
    _sesiones = const [];
    _asistencias = const {};
    _cargando = true;
    _error = null;
    _subInscritos = _servicio.inscritos(cursoId).listen((lista) {
      _inscritos = lista;
      _cargando = false;
      notifyListeners();
    }, onError: _alFallar);
    _subSesiones = _servicio.sesiones(cursoId).listen((lista) {
      _sesiones = lista;
      _cargando = false;
      notifyListeners();
      _cargarAsistencias(cursoId, lista);
    }, onError: _alFallar);
    // Se notifica después del build en curso, desde donde se suele llamar.
    scheduleMicrotask(notifyListeners);
  }

  Future<void> _cargarAsistencias(String cursoId, List<Sesion> sesiones) async {
    try {
      final leidas = await _servicio.asistenciasDeSesiones(
        cursoId,
        sesiones.map((s) => s.id).toList(),
      );
      // Otra emisión pudo cambiar de curso mientras se leían.
      if (_desechado || _cursoId != cursoId) return;
      _asistencias = leidas;
      notifyListeners();
    } on CursoException catch (e) {
      if (_desechado) return;
      _error = e.mensaje;
      notifyListeners();
    }
  }

  /// Deja de escuchar el curso (por ejemplo, antes de borrarlo).
  void detener() {
    _subInscritos?.cancel();
    _subSesiones?.cancel();
    _subInscritos = null;
    _subSesiones = null;
    _cursoId = null;
  }

  void _alFallar(Object e) {
    _cargando = false;
    _error = e.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _subInscritos?.cancel();
    _subSesiones?.cancel();
    super.dispose();
  }
}
