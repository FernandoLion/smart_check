import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
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

  /// La asistencia media de cada curso, por id; falta mientras se calcula.
  final _promedios = <String, AsistenciaResumen>{};
  AsistenciaResumen? promedioDe(String cursoId) => _promedios[cursoId];
  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;

  /// Empieza a escuchar los cursos de [docenteUid]. Llamarlo otra vez con el
  /// mismo uid no hace nada, salvo que la escucha haya fallado: entonces lo
  /// intenta de nuevo. Con otro uid, cambia de docente.
  void vigilarCursos(String docenteUid) {
    if (_docenteUid == docenteUid && _error == null) return;
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
        _cargarPromedios(_cursos);
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

  /// Deja de escuchar y olvida al docente. Va antes de cerrar sesión, por lo
  /// mismo que en el portal del estudiante: una escucha abierta sin usuario
  /// termina en "permiso denegado".
  void dejarDeVigilar() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _docenteUid = null;
    _cursos = const [];
    _promedios.clear();
    _error = null;
    _cargando = false;
    notifyListeners();
  }

  /// Crea el curso e inscribe a [inscritos]. Devuelve el id del curso, o null
  /// si falló (el motivo queda en [error]).
  /// Calcula la asistencia media de cada curso. Si una falla, esa tarjeta
  /// sigue mostrando el guion: el resto del panel no depende de esto.
  Future<void> _cargarPromedios(List<Curso> cursos) async {
    for (final curso in cursos) {
      try {
        final promedio = await _servicio.promedioDelCurso(curso.id);
        if (!_desechado) {
          _promedios[curso.id] = promedio;
          notifyListeners();
        }
      } catch (_) {
        // Sin conexión o sin permiso: queda el guion.
      }
    }
  }

  bool _desechado = false;

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

  /// Borra el curso con todo lo que tiene. Devuelve false si falló.
  Future<bool> eliminarCurso(String cursoId) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      await _servicio.eliminarCurso(cursoId);
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// Guarda los cambios de [curso] e inscribe a [nuevos], si hay.
  Future<bool> editarCurso(Curso curso, List<Inscrito> nuevos) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      await _servicio.editarCurso(curso);
      if (nuevos.isNotEmpty) await _servicio.inscribir(curso.id, nuevos);
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// Saca a [inscrito] del curso. Sus asistencias pasadas se quedan en las
  /// sesiones, pero ya no cuentan en la lista ni en los porcentajes.
  Future<bool> quitarInscrito(String cursoId, Inscrito inscrito) async {
    _error = null;
    try {
      await _servicio.quitarInscrito(cursoId, inscrito);
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      notifyListeners();
      return false;
    }
  }

  /// Archiva el curso o lo vuelve a activar. La lista se actualiza sola
  /// cuando Firestore confirma el cambio.
  Future<bool> archivarCurso(String cursoId, {required bool archivado}) async {
    _error = null;
    try {
      await _servicio.archivarCurso(cursoId, archivado: archivado);
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _suscripcion?.cancel();
    super.dispose();
  }
}
