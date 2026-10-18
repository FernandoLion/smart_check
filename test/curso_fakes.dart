import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/services/curso_service.dart';

/// Cursos en memoria, con los mismos efectos que el servicio real.
class FakeCursoService extends Fake implements CursoService {
  final cursos = <String, Curso>{};
  final inscritosPorCurso = <String, Map<String, Inscrito>>{};
  CursoException? fallo;
  final _cambios = StreamController<void>.broadcast();
  var _siguienteId = 1;

  @override
  Stream<List<Curso>> cursosDelDocente(String docenteUid) async* {
    yield _delDocente(docenteUid);
    await for (final _ in _cambios.stream) {
      yield _delDocente(docenteUid);
    }
  }

  List<Curso> _delDocente(String uid) =>
      cursos.values.where((c) => c.docenteUid == uid).toList();

  @override
  Future<String> crearCurso(Curso curso) async {
    if (fallo != null) throw fallo!;
    final id = 'curso-${_siguienteId++}';
    cursos[id] = Curso.fromMap(id, curso.toMap());
    _cambios.add(null);
    return id;
  }

  @override
  Future<void> inscribir(String cursoId, List<Inscrito> nuevos) async {
    if (fallo != null) throw fallo!;
    final inscritos = inscritosPorCurso.putIfAbsent(cursoId, () => {});
    for (final n in nuevos) {
      inscritos[n.clave] = n;
    }
    final curso = cursos[cursoId]!;
    cursos[cursoId] = Curso.fromMap(cursoId, {
      ...curso.toMap(),
      'claves_inscritos': {
        ...curso.clavesInscritos,
        ...nuevos.expand((n) => n.claves),
      }.toList(),
      'total_inscritos': inscritos.length,
    });
    _cambios.add(null);
  }
}
