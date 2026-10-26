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

  CourseDetailViewModel({CursoService? servicio})
      : _servicio = servicio ?? CursoService();

  StreamSubscription<List<Inscrito>>? _subInscritos;
  StreamSubscription<List<Sesion>>? _subSesiones;
  String? _cursoId;

  List<Inscrito> _inscritos = const [];
  List<Sesion> _sesiones = const [];
  Map<String, List<Asistencia>> _asistencias = const {};
  bool _cargando = false;
  String? _error;

  bool get cargando => _cargando;
  String? get error => _error;
  int get totalInscritos => _inscritos.length;

  /// Las sesiones de la más reciente a la más antigua.
  List<Sesion> get sesiones => _sesiones;

  /// La sesión que el docente dejó abierta, si hay alguna.
  Sesion? get sesionAbierta {
    for (final s in _sesiones) {
      if (s.abierta) return s;
    }
    return null;
  }

  List<SesionResumen> get sesionesPasadas => _sesiones
      .where((s) => !s.abierta)
      .map(
        (s) => SesionResumen(
          s,
          _asistencias[s.id]?.where((a) => a.cuentaComoAsistio).length ?? 0,
          _inscritos.length,
        ),
      )
      .toList();

  /// Los inscritos con su asistencia, los de mayor riesgo primero.
  List<InscritoAsistencia> get inscritos {
    final terminadas = _sesiones.where((s) => !s.abierta).toList();
    final asistidasPor = <String, int>{};
    for (final sesion in terminadas) {
      for (final a in _asistencias[sesion.id] ?? const <Asistencia>[]) {
        if (a.cuentaComoAsistio) {
          asistidasPor[a.claveInscrito] =
              (asistidasPor[a.claveInscrito] ?? 0) + 1;
        }
      }
    }
    final lista = _inscritos
        .map(
          (i) => InscritoAsistencia(
            i,
            AsistenciaResumen(
              sesiones: terminadas.length,
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

  /// Asistencia media del curso sobre todas las sesiones ya cerradas.
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
      if (_cursoId != cursoId) return;
      _asistencias = leidas;
      notifyListeners();
    } on CursoException catch (e) {
      _error = e.mensaje;
      notifyListeners();
    }
  }

  void _alFallar(Object e) {
    _cargando = false;
    _error = e.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    _subInscritos?.cancel();
    _subSesiones?.cancel();
    super.dispose();
  }
}
