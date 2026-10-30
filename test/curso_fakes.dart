import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/presencia_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/curso_service.dart';

/// Cursos en memoria, con los mismos efectos que el servicio real.
class FakeCursoService extends Fake implements CursoService {
  final cursos = <String, Curso>{};
  final inscritosPorCurso = <String, Map<String, Inscrito>>{};

  final sesionesPorCurso = <String, List<Sesion>>{};

  /// Asistencias por id de sesión.
  final asistenciasPorSesion = <String, List<Asistencia>>{};

  /// Presencias firmadas por id de sesión, en el orden en que llegaron.
  final presenciasPorSesion = <String, List<Presencia>>{};

  /// Para probar que el servidor rechaza la asistencia de quien no firmó.
  CursoException? falloAlFirmar;

  /// Asistencia ya calculada por curso, como la devolvería Firestore.
  final resumenes = <String, AsistenciaResumen>{};
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
  Future<AsistenciaResumen> resumenAsistencia(
    String cursoId,
    List<String> claves, {
    DateTime? ahora,
  }) async {
    if (fallo != null) throw fallo!;
    return resumenes[cursoId] ?? const AsistenciaResumen();
  }

  @override
  Stream<List<Inscrito>> inscritos(String cursoId) async* {
    List<Inscrito> actuales() =>
        (inscritosPorCurso[cursoId] ?? const {}).values.toList();
    yield actuales();
    await for (final _ in _cambios.stream) {
      yield actuales();
    }
  }

  @override
  Stream<List<Sesion>> sesiones(String cursoId) async* {
    // El servicio real las entrega de la más reciente a la más antigua.
    List<Sesion> actuales() => [...sesionesPorCurso[cursoId] ?? const []]
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
    yield actuales();
    await for (final _ in _cambios.stream) {
      yield actuales();
    }
  }

  @override
  Future<Map<String, List<Asistencia>>> asistenciasDeSesiones(
    String cursoId,
    List<String> sesionIds,
  ) async {
    if (fallo != null) throw fallo!;
    return {
      for (final id in sesionIds) id: asistenciasPorSesion[id] ?? const [],
    };
  }

  @override
  Stream<List<Sesion>> llamadosAbiertos(String cursoId) async* {
    List<Sesion> abiertos() =>
        (sesionesPorCurso[cursoId] ?? const <Sesion>[])
            .where((s) => s.abierta)
            .toList();
    yield abiertos();
    await for (final _ in _cambios.stream) {
      yield abiertos();
    }
  }

  @override
  Future<String> abrirSesion(String cursoId, Sesion sesion) async {
    if (fallo != null) throw fallo!;
    final id = 'sesion-${_siguienteId++}';
    sesionesPorCurso.putIfAbsent(cursoId, () => []).add(sesion.copyWith(id: id));
    _cambios.add(null);
    return id;
  }

  @override
  Future<void> cerrarSesion(String cursoId, String sesionId) async {
    if (fallo != null) throw fallo!;
    final lista = sesionesPorCurso[cursoId] ?? [];
    for (var i = 0; i < lista.length; i++) {
      if (lista[i].id != sesionId) continue;
      lista[i] = lista[i].copyWith(abierta: false);
    }
    _cambios.add(null);
  }

  /// La sesión tal como quedó guardada, para comprobarla en los tests.
  Sesion sesion(String cursoId, String sesionId) =>
      sesionesPorCurso[cursoId]!.firstWhere((s) => s.id == sesionId);

  @override
  Stream<List<Asistencia>> asistencias(String cursoId, String sesionId) async* {
    yield asistenciasPorSesion[sesionId] ?? const [];
    await for (final _ in _cambios.stream) {
      yield asistenciasPorSesion[sesionId] ?? const [];
    }
  }

  @override
  Future<void> registrarAsistencia(
    String cursoId,
    String sesionId,
    Asistencia asistencia,
  ) async {
    if (fallo != null) throw fallo!;
    final lista = asistenciasPorSesion.putIfAbsent(sesionId, () => [])
      ..removeWhere((a) => a.claveInscrito == asistencia.claveInscrito);
    lista.add(asistencia);
    _cambios.add(null);
  }

  @override
  Future<void> firmarPresencia(
    String cursoId,
    String sesionId,
    Presencia presencia,
  ) async {
    if (falloAlFirmar != null) throw falloAlFirmar!;
    if (fallo != null) throw fallo!;
    presenciasPorSesion.putIfAbsent(sesionId, () => []).add(presencia);
    _cambios.add(null);
  }

  @override
  Stream<List<Presencia>> presencias(String cursoId, String sesionId) async* {
    yield presenciasPorSesion[sesionId] ?? const [];
    await for (final _ in _cambios.stream) {
      yield presenciasPorSesion[sesionId] ?? const [];
    }
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
  Future<void> eliminarCurso(String cursoId) async {
    if (fallo != null) throw fallo!;
    for (final sesion in sesionesPorCurso.remove(cursoId) ?? const <Sesion>[]) {
      asistenciasPorSesion.remove(sesion.id);
    }
    inscritosPorCurso.remove(cursoId);
    cursos.remove(cursoId);
    _cambios.add(null);
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
