import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/curso_model.dart';
import '../models/inscrito_model.dart';
import '../models/sesion_model.dart';

/// Error al leer o guardar cursos, con un mensaje listo para mostrar.
class CursoException implements Exception {
  final String mensaje;
  const CursoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Asistencia de un estudiante en un curso: a cuántas de las sesiones que ya
/// terminaron asistió.
class ResumenAsistencia {
  final int sesiones;
  final int asistidas;

  const ResumenAsistencia({this.sesiones = 0, this.asistidas = 0});
}

/// Cursos, inscritos, sesiones y asistencias en Firestore:
///
/// ```
/// cursos/{cursoId}
///   inscritos/{clave}               (cédula o correo)
///   sesiones/{sesionId}
///     asistencias/{claveInscrito}
/// ```
class CursoService {
  static const _timeout = Duration(seconds: 15);

  // Se resuelve al usarse (Firebase puede no estar inicializado en los tests).
  CollectionReference<Map<String, dynamic>> get _cursos =>
      FirebaseFirestore.instance.collection('cursos');

  CollectionReference<Map<String, dynamic>> _inscritos(String cursoId) =>
      _cursos.doc(cursoId).collection('inscritos');

  CollectionReference<Map<String, dynamic>> _sesiones(String cursoId) =>
      _cursos.doc(cursoId).collection('sesiones');

  CollectionReference<Map<String, dynamic>> _asistencias(
    String cursoId,
    String sesionId,
  ) =>
      _sesiones(cursoId).doc(sesionId).collection('asistencias');

  // --- Cursos ---------------------------------------------------------------

  Stream<List<Curso>> cursosDelDocente(String docenteUid) => _cursos
      .where('docente_uid', isEqualTo: docenteUid)
      .snapshots()
      .map((s) => s.docs.map((d) => Curso.fromMap(d.id, d.data())).toList())
      .handleError((Object e) => throw CursoException(_mensaje(e, 'leer tus cursos')));

  /// Cursos donde aparece la cédula o el correo del estudiante.
  Stream<List<Curso>> cursosDelEstudiante({String? cedula, String? email}) {
    final claves = [
      if (cedula != null && cedula.isNotEmpty) cedula,
      if (email != null && email.isNotEmpty) email.toLowerCase(),
    ];
    if (claves.isEmpty) return Stream.value(const []);
    return _cursos
        .where('claves_inscritos', arrayContainsAny: claves)
        .snapshots()
        .map((s) => s.docs.map((d) => Curso.fromMap(d.id, d.data())).toList())
        .handleError((Object e) => throw CursoException(_mensaje(e, 'leer tus cursos')));
  }

  /// Crea el curso y devuelve su id.
  Future<String> crearCurso(Curso curso) async {
    try {
      final ref = await _cursos
          .add({...curso.toMap(), 'creado_en': FieldValue.serverTimestamp()})
          .timeout(_timeout);
      return ref.id;
    } catch (e) {
      throw CursoException(_mensaje(e, 'crear el curso'));
    }
  }

  // --- Inscritos ------------------------------------------------------------

  Stream<List<Inscrito>> inscritos(String cursoId) => _inscritos(cursoId)
      .snapshots()
      .map((s) => s.docs.map((d) => Inscrito.fromMap(d.data())).toList())
      .handleError((Object e) => throw CursoException(_mensaje(e, 'leer los inscritos')));

  /// Agrega o actualiza inscritos (CSV, cédula o correo) en una sola escritura.
  /// Firestore admite hasta 500 operaciones por lote; cada inscrito usa una.
  Future<void> inscribir(String cursoId, List<Inscrito> nuevos) async {
    if (nuevos.isEmpty) return;
    try {
      for (var i = 0; i < nuevos.length; i += 450) {
        final parte = nuevos.skip(i).take(450).toList();
        final batch = FirebaseFirestore.instance.batch();
        for (final inscrito in parte) {
          batch.set(_inscritos(cursoId).doc(inscrito.clave), inscrito.toMap());
        }
        batch.update(_cursos.doc(cursoId), {
          'claves_inscritos':
              FieldValue.arrayUnion(parte.expand((n) => n.claves).toList()),
        });
        await batch.commit().timeout(_timeout);
      }
      await _actualizarTotal(cursoId);
    } catch (e) {
      throw CursoException(_mensaje(e, 'inscribir a los estudiantes'));
    }
  }

  /// Guarda en el curso cuántos inscritos tiene (un mismo estudiante puede
  /// aparecer por cédula y por correo en [Curso.clavesInscritos]).
  Future<void> _actualizarTotal(String cursoId) async {
    final conteo = await _inscritos(cursoId).count().get().timeout(_timeout);
    await _cursos
        .doc(cursoId)
        .update({'total_inscritos': conteo.count ?? 0}).timeout(_timeout);
  }

  Future<void> quitarInscrito(String cursoId, Inscrito inscrito) async {
    try {
      final batch = FirebaseFirestore.instance.batch()
        ..delete(_inscritos(cursoId).doc(inscrito.clave))
        ..update(_cursos.doc(cursoId), {
          'claves_inscritos': FieldValue.arrayRemove(inscrito.claves),
        });
      await batch.commit().timeout(_timeout);
      await _actualizarTotal(cursoId);
    } catch (e) {
      throw CursoException(_mensaje(e, 'quitar al estudiante'));
    }
  }

  // --- Sesiones -------------------------------------------------------------

  Stream<List<Sesion>> sesiones(String cursoId) => _sesiones(cursoId)
      .orderBy('inicio', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Sesion.fromMap(d.id, d.data())).toList())
      .handleError((Object e) => throw CursoException(_mensaje(e, 'leer las sesiones')));

  /// Abre una sesión y devuelve su id.
  Future<String> abrirSesion(String cursoId, Sesion sesion) async {
    try {
      final ref = await _sesiones(cursoId).add(sesion.toMap()).timeout(_timeout);
      return ref.id;
    } catch (e) {
      throw CursoException(_mensaje(e, 'abrir la sesión'));
    }
  }

  Future<void> cerrarSesion(String cursoId, String sesionId) async {
    try {
      await _sesiones(cursoId)
          .doc(sesionId)
          .update({'abierta': false}).timeout(_timeout);
    } catch (e) {
      throw CursoException(_mensaje(e, 'cerrar la sesión'));
    }
  }

  // --- Asistencias ----------------------------------------------------------

  Stream<List<Asistencia>> asistencias(String cursoId, String sesionId) =>
      _asistencias(cursoId, sesionId)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => Asistencia.fromMap(d.id, d.data())).toList())
          .handleError((Object e) =>
              throw CursoException(_mensaje(e, 'leer las asistencias')));

  /// Guarda (o corrige) la asistencia de un inscrito a una sesión.
  Future<void> registrarAsistencia(
    String cursoId,
    String sesionId,
    Asistencia asistencia,
  ) async {
    try {
      await _asistencias(cursoId, sesionId)
          .doc(asistencia.claveInscrito)
          .set(asistencia.toMap())
          .timeout(_timeout);
    } catch (e) {
      throw CursoException(_mensaje(e, 'registrar la asistencia'));
    }
  }

  /// Asistencia del estudiante en un curso. Solo cuentan las sesiones que ya
  /// terminaron: las que siguen en curso aún no son una falta.
  ///
  /// [claves] son la cédula y el correo, porque el docente pudo inscribirlo
  /// por cualquiera de los dos.
  Future<ResumenAsistencia> resumenAsistencia(
    String cursoId,
    List<String> claves, {
    DateTime? ahora,
  }) async {
    if (claves.isEmpty) return const ResumenAsistencia();
    final momento = ahora ?? DateTime.now();
    try {
      final docs = await _sesiones(cursoId).get().timeout(_timeout);
      final terminadas = docs.docs
          .map((d) => Sesion.fromMap(d.id, d.data()))
          .where((s) => s.fin.isBefore(momento))
          .toList();
      final asistio = await Future.wait(
        terminadas.map((s) => _asistio(cursoId, s.id, claves)),
      );
      return ResumenAsistencia(
        sesiones: terminadas.length,
        asistidas: asistio.where((a) => a).length,
      );
    } catch (e) {
      throw CursoException(_mensaje(e, 'leer tu asistencia'));
    }
  }

  Future<bool> _asistio(
    String cursoId,
    String sesionId,
    List<String> claves,
  ) async {
    for (final clave in claves) {
      final doc = await _asistencias(cursoId, sesionId).doc(clave).get();
      final data = doc.data();
      if (data != null) return Asistencia.fromMap(clave, data).cuentaComoAsistio;
    }
    return false;
  }

  static String _mensaje(Object e, String accion) {
    if (e is TimeoutException) {
      return 'No se pudo $accion: el servidor no respondió a tiempo.';
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'No se pudo $accion: permiso denegado en la base de datos.';
    }
    if (e is FirebaseException && e.code == 'unavailable') {
      return 'No se pudo $accion: sin conexión con la base de datos.';
    }
    return 'No se pudo $accion: $e';
  }
}
