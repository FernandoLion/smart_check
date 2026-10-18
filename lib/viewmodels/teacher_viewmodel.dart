import 'dart:async';

import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../models/inscrito_model.dart';
import '../services/curso_service.dart';

/// ViewModel del panel docente: sus cursos en Firestore, crear cursos e
/// inscribir estudiantes.
class TeacherViewModel extends ChangeNotifier {
  final CursoService _servicio;

  TeacherViewModel({CursoService? servicio})
      : _servicio = servicio ?? CursoService();

  StreamSubscription<List<Curso>>? _suscripcion;
  String? _docenteUid;

  List<Curso> _cursos = const [];
  bool _cargando = false;
  bool _guardando = false;
  String? _error;

  List<Curso> get cursos => _cursos;
  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;

  /// Empieza a escuchar los cursos de [docenteUid]. Llamarlo otra vez con el
  /// mismo uid no hace nada; con otro, cambia de docente.
  void vigilarCursos(String docenteUid) {
    if (_docenteUid == docenteUid) return;
    _suscripcion?.cancel();
    _docenteUid = docenteUid;
    _cursos = const [];
    _cargando = true;
    _error = null;
    _suscripcion = _servicio.cursosDelDocente(docenteUid).listen(
      (cursos) {
        _cursos = [...cursos]..sort((a, b) => a.nombre.compareTo(b.nombre));
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _cargando = false;
        _error = e.toString();
        notifyListeners();
      },
    );
    // Se notifica después del build en curso, desde donde se suele llamar.
    scheduleMicrotask(notifyListeners);
  }

  /// Crea el curso e inscribe a [inscritos]. Devuelve el id del curso, o null
  /// si falló (el motivo queda en [error]).
  Future<String?> crearCurso(Curso curso, List<Inscrito> inscritos) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final id = await _servicio.crearCurso(curso);
      await _servicio.inscribir(id, inscritos);
      return id;
    } on CursoException catch (e) {
      _error = e.mensaje;
      return null;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// Inscribe estudiantes en un curso existente. Devuelve false si falló.
  Future<bool> inscribir(String cursoId, List<Inscrito> inscritos) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      await _servicio.inscribir(cursoId, inscritos);
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
