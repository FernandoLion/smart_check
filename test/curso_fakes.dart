import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/services/curso_service.dart';

/// Cursos en memoria, con los mismos efectos que el servicio real.
class FakeCursoService extends Fake implements CursoService {
  final cursos = <String, Curso>{};
  final inscritosPorCurso = <String, Map<String, Inscrito>>{};

  /// Asistencia ya calculada por curso, como la devolvería Firestore.
  final resumenes = <String, ResumenAsistencia>{};
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

  List<Curso> _delDocente(String uid) => _conId((c) => c.docenteUid == uid);

  /// Firestore siempre entrega el id del documento; el mapa es la fuente.
  List<Curso> _conId(bool Function(Curso) filtro) => cursos.entries
      .map((e) => Curso.fromMap(e.key, e.value.toMap()))
      .where(filtro)
      .toList();

  @override
  Stream<List<Curso>> cursosDelEstudiante({
    String? cedula,
    String? email,
  }) async* {
    final claves = [
      if (cedula != null && cedula.isNotEmpty) cedula,
      if (email != null && email.isNotEmpty) email.toLowerCase(),
    ];
    if (claves.isEmpty) {
      yield const [];
      return;
    }
    yield _inscritoEn(claves);
    await for (final _ in _cambios.stream) {
      yield _inscritoEn(claves);
    }
  }

  List<Curso> _inscritoEn(List<String> claves) =>
      _conId((c) => c.clavesInscritos.any(claves.contains));

  @override
  Future<ResumenAsistencia> resumenAsistencia(
    String cursoId,
    List<String> claves, {
    DateTime? ahora,
  }) async {
    if (fallo != null) throw fallo!;
    return resumenes[cursoId] ?? const ResumenAsistencia();
  }

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
