import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/asistencia_resumen.dart';
import '../models/curso_model.dart';
import '../models/inscrito_model.dart';
import '../models/presencia_model.dart';
import '../models/sesion_model.dart';

/// Error al leer o guardar cursos, con un mensaje listo para mostrar.
class CursoException implements Exception {
  final String mensaje;

  /// El código de Firestore, cuando lo hay (`permission-denied`,
  /// `unavailable`...). Quien llama suele mostrar solo [mensaje], pero el
  /// radar necesita distinguir "el servidor dijo que no" de "no hubo red".
  final String? codigo;

  const CursoException(this.mensaje, [this.codigo]);

  /// Si el servidor rechazó la escritura. En las asistencias por BLE esto
  /// significa, casi siempre, que el estudiante todavía no ha firmado.
  bool get denegado => codigo == 'permission-denied';

  @override
  String toString() => mensaje;
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

  CollectionReference<Map<String, dynamic>> _presencias(
    String cursoId,
    String sesionId,
  ) =>
      _sesiones(cursoId).doc(sesionId).collection('presencias');

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

  /// Borra el curso con sus inscritos, sesiones, asistencias y presencias.
  ///
  /// Firestore no borra las subcolecciones junto con el documento, así que se
  /// borran primero (las reglas consultan el curso para autorizarlas) y el
  /// curso al final.
  Future<void> eliminarCurso(String cursoId) async {
    try {
      final sesiones = await _sesiones(cursoId).get().timeout(_timeout);
      final asistencias = await Future.wait(
        sesiones.docs.map(
          (s) => _asistencias(cursoId, s.id).get().timeout(_timeout),
        ),
      );
      final presencias = await Future.wait(
        sesiones.docs.map(
          (s) => _presencias(cursoId, s.id).get().timeout(_timeout),
        ),
      );
      final inscritos = await _inscritos(cursoId).get().timeout(_timeout);
      final hijos = [
        for (final lote in asistencias) ...lote.docs.map((d) => d.reference),
        for (final lote in presencias) ...lote.docs.map((d) => d.reference),
        ...sesiones.docs.map((d) => d.reference),
        ...inscritos.docs.map((d) => d.reference),
      ];
      for (var i = 0; i < hijos.length; i += 450) {
        final batch = FirebaseFirestore.instance.batch();
        for (final ref in hijos.skip(i).take(450)) {
          batch.delete(ref);
        }
        await batch.commit().timeout(_timeout);
      }
      await _cursos.doc(cursoId).delete().timeout(_timeout);
    } catch (e) {
      throw CursoException(_mensaje(e, 'eliminar el curso'));
    }
  }

  /// Guarda lo que el docente puede editar del curso. Los inscritos, el
  /// periodo y el docente no se tocan aquí.
  Future<void> editarCurso(Curso curso) async {
    try {
      await _cursos.doc(curso.id).update({
        'codigo': curso.codigo,
        'nombre': curso.nombre,
        'grupo': curso.grupo,
        'aula': curso.aula,
        'horarios': curso.horarios.map((h) => h.toMap()).toList(),
        'geocerca': curso.geocerca?.toMap(),
      }).timeout(_timeout);
    } catch (e) {
      throw CursoException(_mensaje(e, 'guardar el curso'));
    }
  }

  /// Archiva el curso o lo devuelve a la lista activa. Solo cambia esa
  /// bandera: inscritos y asistencias se quedan como estaban.
  Future<void> archivarCurso(String cursoId, {required bool archivado}) async {
    try {
      await _cursos
          .doc(cursoId)
          .update({'archivado': archivado}).timeout(_timeout);
    } catch (e) {
      throw CursoException(
        _mensaje(e, archivado ? 'archivar el curso' : 'activar el curso'),
      );
    }
  }

  /// Cambia la geocerca del aula, o la quita con null.
  Future<void> cambiarGeocerca(String cursoId, Geocerca? geocerca) async {
    try {
      await _cursos
          .doc(cursoId)
          .update({'geocerca': geocerca?.toMap()}).timeout(_timeout);
    } catch (e) {
      throw CursoException(_mensaje(e, 'guardar la geocerca'));
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
      // A los que ya estaban no se les cambia la fecha de inscripción: si
      // no, volver a pegar la lista les borraría las faltas de antes.
      final yaEstaban = (await _inscritos(cursoId).get().timeout(_timeout))
          .docs
          .map((d) => d.id)
          .toSet();
      for (var i = 0; i < nuevos.length; i += 450) {
        final parte = nuevos.skip(i).take(450).toList();
        final batch = FirebaseFirestore.instance.batch();
        for (final inscrito in parte) {
          final doc = _inscritos(cursoId).doc(inscrito.clave);
          if (yaEstaban.contains(inscrito.clave)) {
            batch.set(doc, inscrito.toMap(), SetOptions(merge: true));
          } else {
            batch.set(doc, {
              ...inscrito.toMap(),
              'inscrito_en': FieldValue.serverTimestamp(),
            });
          }
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

  /// Los llamados marcados como abiertos. Normalmente hay uno o ninguno: el
  /// radar cierra el suyo al vencer la ventana y, si la app murió antes,
  /// cierra el que quedó colgado al volver a entrar. Sin `orderBy` a
  /// propósito: una igualdad sola usa el índice automático de Firestore y así
  /// no hace falta declarar un índice compuesto.
  Stream<List<Sesion>> llamadosAbiertos(String cursoId) => _sesiones(cursoId)
      .where('abierta', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Sesion.fromMap(d.id, d.data())).toList())
      .handleError((Object e) => throw CursoException(_mensaje(e, 'leer el llamado')));

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
      throw CursoException(_mensaje(e, 'registrar la asistencia'), _codigo(e));
    }
  }

  /// La marca que cuenta de un estudiante en la clase de [franja], sumando
  /// todos los llamados que el docente abrió en ese bloque (pudo cerrar el
  /// radar y volver a abrirlo). null si no tiene ninguna. [claves] son su
  /// cédula y su correo, porque lo pudieron inscribir por cualquiera.
  Future<Asistencia?> miMarcaEnLaFranja(
    String cursoId,
    DateTime franja,
    List<String> claves,
  ) async {
    final llamados =
        (await sesiones(cursoId).first).where((s) => s.franja == franja);
    try {
      final marcas = <Asistencia>[];
      for (final s in llamados) {
        final marca = await _marcaDe(cursoId, s.id, claves);
        if (marca != null) marcas.add(marca);
      }
      return marcaQueCuenta(marcas);
    } catch (e) {
      throw CursoException(_mensaje(e, 'revisar tu asistencia'));
    }
  }

  /// La asistencia del estudiante en un llamado, en vivo: aparece en cuanto
  /// el radar del docente lo registra. null mientras no tenga.
  Stream<Asistencia?> miAsistencia(
    String cursoId,
    String sesionId,
    List<String> claves,
  ) {
    final ultimas = <String, Asistencia?>{};
    final suscripciones = <StreamSubscription<Object?>>[];
    late final StreamController<Asistencia?> salida;
    salida = StreamController<Asistencia?>(
      onListen: () {
        for (final clave in claves) {
          suscripciones.add(
            _asistencias(cursoId, sesionId).doc(clave).snapshots().listen(
              (doc) {
                final data = doc.data();
                ultimas[clave] =
                    data == null ? null : Asistencia.fromMap(clave, data);
                salida.add(ultimas.values.whereType<Asistencia>().firstOrNull);
              },
              onError: salida.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final s in suscripciones) {
          await s.cancel();
        }
      },
    );
    return salida.stream;
  }

  // --- Presencias (la firma del estudiante) ---------------------------------

  /// Las firmas que los estudiantes dejaron en este llamado.
  Stream<List<Presencia>> presencias(String cursoId, String sesionId) =>
      _presencias(cursoId, sesionId)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => Presencia.fromMap(d.id, d.data())).toList())
          .handleError((Object e) =>
              throw CursoException(_mensaje(e, 'leer las presencias')));

  /// El estudiante firma que está aquí, desde su celular vinculado.
  ///
  /// Sin esto el servidor rechaza la asistencia por BLE, así que si falla no
  /// hay que emitir la baliza: el docente no podría registrarla.
  Future<void> firmarPresencia(
    String cursoId,
    String sesionId,
    Presencia presencia,
  ) async {
    try {
      await _presencias(cursoId, sesionId)
          .doc(presencia.claveInscrito)
          .set(presencia.toMap())
          .timeout(_timeout);
    } catch (e) {
      throw CursoException(_mensaje(e, 'firmar tu asistencia'), _codigo(e));
    }
  }

  /// Asistencia del estudiante en un curso. Solo cuentan las sesiones que ya
  /// terminaron: las que siguen en curso aún no son una falta.
  ///
  /// [claves] son la cédula y el correo, porque el docente pudo inscribirlo
  /// por cualquiera de los dos.
  Future<AsistenciaResumen> resumenAsistencia(
    String cursoId,
    List<String> claves, {
    DateTime? ahora,
  }) async =>
      AsistenciaResumen.de(
        await historialAsistencia(cursoId, claves, ahora: ahora),
      );

  /// Cada clase terminada de [cursoId], de la más reciente a la más antigua,
  /// con la marca que decide si el estudiante de [claves] asistió.
  Future<List<ClaseDelEstudiante>> historialAsistencia(
    String cursoId,
    List<String> claves, {
    DateTime? ahora,
  }) async {
    if (claves.isEmpty) return const [];
    final momento = ahora ?? DateTime.now();
    try {
      final inscripcion = await _inscripcionDe(cursoId, claves);
      final docs = await _sesiones(cursoId).get().timeout(_timeout);
      final porFranja = franjasTerminadas(
        docs.docs.map((d) => Sesion.fromMap(d.id, d.data())).toList(),
        momento,
      );
      final clases = await Future.wait(
        porFranja.entries.map((franja) async {
          final marcas = await Future.wait(
            franja.value.map((s) => _marcaDe(cursoId, s.id, claves)),
          );
          return ClaseDelEstudiante(
            franja.key,
            marcaQueCuenta(marcas.whereType<Asistencia>()),
          );
        }),
      );
      return clases
          .where(
            (c) =>
                inscripcion == null ||
                !c.franja.isBefore(inscripcion) ||
                c.asistio,
          )
          .toList()
        ..sort((a, b) => b.franja.compareTo(a.franja));
    } catch (e) {
      throw CursoException(_mensaje(e, 'leer tu asistencia'));
    }
  }

  /// Cuándo inscribieron en [cursoId] al estudiante de [claves], o null si
  /// no se sabe (inscritos de antes de guardar la fecha).
  Future<DateTime?> _inscripcionDe(String cursoId, List<String> claves) async {
    for (final clave in claves) {
      final doc = await _inscritos(cursoId).doc(clave).get().timeout(_timeout);
      final data = doc.data();
      if (data != null) return Inscrito.fromMap(data).inscritoEn;
    }
    return null;
  }

  /// De las marcas de un inscrito en los llamados de una misma clase, la que
  /// decide: si alguna cuenta como asistida, la primera de esas; si no, la
  /// última (una corrección a mano que lo dejó ausente). null si no hay.
  static Asistencia? marcaQueCuenta(Iterable<Asistencia> marcas) {
    final orden = marcas.toList()..sort((a, b) => a.hora.compareTo(b.hora));
    if (orden.isEmpty) return null;
    for (final a in orden) {
      if (a.cuentaComoAsistio) return a;
    }
    return orden.last;
  }

  /// La marca que cuenta de cada inscrito en una clase, juntando las de
  /// todos sus [llamados] ([marcas] va por id de llamado).
  static Map<String, Asistencia> marcasDeLaClase(
    Iterable<Sesion> llamados,
    Map<String, List<Asistencia>> marcas,
  ) {
    final porClave = <String, List<Asistencia>>{};
    for (final s in llamados) {
      for (final a in marcas[s.id] ?? const <Asistencia>[]) {
        (porClave[a.claveInscrito] ??= []).add(a);
      }
    }
    return {
      for (final MapEntry(key: clave, value: suyas) in porClave.entries)
        clave: marcaQueCuenta(suyas)!,
    };
  }

  /// Agrupa por franja de clase los llamados que ya terminaron. Está fuera de
  /// la consulta para poder probarlo: es la cuenta que decide el porcentaje
  /// de asistencia del estudiante.
  ///
  /// Una franja es una clase aunque el docente haya abierto el radar varias
  /// veces dentro del bloque. El llamado que sigue vigente todavía no resta;
  /// el que se pasó de su hora sin cerrarse, sí.
  static Map<DateTime, List<Sesion>> franjasTerminadas(
    List<Sesion> sesiones,
    DateTime momento,
  ) {
    final porFranja = <DateTime, List<Sesion>>{};
    for (final s in sesiones) {
      if (s.abierta && !s.vencida(momento)) continue;
      porFranja.putIfAbsent(s.franja, () => []).add(s);
    }
    return porFranja;
  }

  /// Las asistencias de cada sesión, por id de sesión. Con esto el panel
  /// docente arma a la vez el resumen de cada clase y el de cada inscrito.
  Future<Map<String, List<Asistencia>>> asistenciasDeSesiones(
    String cursoId,
    List<String> sesionIds,
  ) async {
    if (sesionIds.isEmpty) return const {};
    try {
      final porSesion = await Future.wait(
        sesionIds
            .map((id) => _asistencias(cursoId, id).get().timeout(_timeout)),
      );
      return {
        for (var i = 0; i < sesionIds.length; i++)
          sesionIds[i]: porSesion[i]
              .docs
              .map((d) => Asistencia.fromMap(d.id, d.data()))
              .toList(),
      };
    } catch (e) {
      throw CursoException(_mensaje(e, 'leer las asistencias'));
    }
  }

  /// Asistencia media del curso: de las clases ya cerradas, cuántas veces
  /// vinieron los inscritos de ahora. Es la misma cuenta del detalle del
  /// curso, para la tarjeta del panel docente.
  Future<AsistenciaResumen> promedioDelCurso(String cursoId) async {
    final lista = await inscritos(cursoId).first;
    final franjas = franjasTerminadas(
      await sesiones(cursoId).first,
      DateTime.now(),
    );
    final marcas = await asistenciasDeSesiones(cursoId, [
      for (final llamados in franjas.values) ...llamados.map((s) => s.id),
    ]);
    return promedioDe(lista, franjas, marcas);
  }

  /// La cuenta de [promedioDelCurso], sin consultas, para probarla.
  static AsistenciaResumen promedioDe(
    List<Inscrito> inscritos,
    Map<DateTime, List<Sesion>> franjas,
    Map<String, List<Asistencia>> marcas,
  ) {
    var sesiones = 0;
    var asistidas = 0;
    for (final MapEntry(key: franja, value: llamados) in franjas.entries) {
      final deLaClase = marcasDeLaClase(llamados, marcas);
      for (final i in inscritos) {
        final marca = deLaClase[i.clave];
        // Una falta justificada no cuenta para nadie.
        if (marca?.justificada ?? false) continue;
        final vino = marca?.cuentaComoAsistio ?? false;
        if (vino) asistidas++;
        if (vino || i.debiaVenir(franja)) sesiones++;
      }
    }
    return AsistenciaResumen(sesiones: sesiones, asistidas: asistidas);
  }

  Future<Asistencia?> _marcaDe(
    String cursoId,
    String sesionId,
    List<String> claves,
  ) async {
    for (final clave in claves) {
      final doc = await _asistencias(cursoId, sesionId).doc(clave).get();
      final data = doc.data();
      if (data != null) return Asistencia.fromMap(clave, data);
    }
    return null;
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

  /// El código de Firestore, para que quien llama pueda distinguir un
  /// rechazo de las reglas de un fallo de red.
  static String? _codigo(Object e) => e is FirebaseException ? e.code : null;
}
