import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
import '../models/curso_model.dart';
import '../models/sesion_model.dart';
import '../models/student_subject_model.dart';
import '../services/curso_service.dart';

/// ViewModel del portal del estudiante: los cursos donde el docente lo
/// inscribió y su asistencia en cada uno.
class StudentViewModel extends ChangeNotifier {
  final CursoService _servicio;

  StudentViewModel({CursoService? servicio})
      : _servicio = servicio ?? CursoService();

  StreamSubscription<List<Curso>>? _suscripcion;
  List<String> _claves = const [];

  /// Un listener por materia: es lo único que enciende el botón de registrar
  /// asistencia. Si el docente no abrió el radar, no hay nada que marcar.
  final _llamados = <String, StreamSubscription<List<Sesion>>>{};
  final _abiertos = <String, Sesion>{};

  /// Apaga el botón en el instante en que se acaba la ventana, en vez de
  /// preguntar la hora cada segundo.
  Timer? _expira;

  List<Curso> _cursos = const [];
  List<StudentSubjectModel> _subjects = const [];
  bool _cargando = false;
  String? _error;

  List<StudentSubjectModel> get subjects => _subjects;

  /// Los cursos tal cual, para la baliza BLE.
  List<Curso> get cursos => _cursos;
  bool get cargando => _cargando;
  String? get error => _error;

  String get currentPeriod => Curso.periodoActual();

  /// La materia cuyo docente tiene el llamado abierto ahora mismo, o null.
  (Curso, Sesion)? get llamadoVigente {
    final ahora = DateTime.now();
    for (final curso in _cursos) {
      final sesion = _abiertos[curso.id];
      if (sesion != null && sesion.admiteAsistencia(ahora)) {
        return (curso, sesion);
      }
    }
    return null;
  }

  /// Si tiene sentido abrir la pantalla de marcar asistencia.
  bool get puedeRegistrar => llamadoVigente != null;

  /// Asistencia media de todas las materias con clases registradas, o null si
  /// todavía no hay ninguna.
  int? get globalAttendance {
    final conClases = _subjects.where((s) => s.sessionsTotal > 0).toList();
    if (conClases.isEmpty) return null;
    final sesiones = conClases.fold(0, (t, s) => t + s.sessionsTotal);
    final asistidas = conClases.fold(0, (t, s) => t + s.sessionsAttended);
    return (asistidas * 100 / sesiones).round();
  }

  String get globalAttendanceStatus {
    final porcentaje = globalAttendance;
    if (porcentaje == null) return 'Sin clases aún';
    if (porcentaje >= 90) return 'Al día';
    if (porcentaje >= AsistenciaResumen.minimo) return 'Atención';
    return 'En riesgo';
  }

  int get materiasEnRiesgo =>
      _subjects.where((s) => s.status == NivelAsistencia.riesgo).length;

  /// Empieza a escuchar los cursos donde el estudiante está inscrito por
  /// [cedula] o por [email]. Volver a llamarlo con los mismos no hace nada.
  void vigilarCursos({String? cedula, String? email}) {
    final claves = [
      if (cedula != null && cedula.isNotEmpty) cedula,
      if (email != null && email.isNotEmpty) email.toLowerCase(),
    ];
    if (_mismasClaves(claves)) return;
    _suscripcion?.cancel();
    _olvidarLlamados();
    _claves = claves;
    _subjects = const [];
    _cursos = const [];
    _error = null;
    _cargando = claves.isNotEmpty;
    if (claves.isEmpty) {
      scheduleMicrotask(notifyListeners);
      return;
    }
    _suscripcion = _servicio
        .cursosDelEstudiante(cedula: cedula, email: email)
        .listen(_alLlegarCursos, onError: (Object e) {
      _cargando = false;
      _error = e.toString();
      notifyListeners();
    });
    // Se notifica después del build en curso, desde donde se suele llamar.
    scheduleMicrotask(notifyListeners);
  }

  bool _mismasClaves(List<String> otras) {
    if (_claves.length != otras.length) return false;
    for (var i = 0; i < otras.length; i++) {
      if (_claves[i] != otras[i]) return false;
    }
    return true;
  }

  Future<void> _alLlegarCursos(List<Curso> cursos) async {
    final ordenados = [...cursos]..sort((a, b) => a.nombre.compareTo(b.nombre));
    _cursos = ordenados;
    _vigilarLlamados(ordenados);
    // Se muestran los cursos de una vez y la asistencia se llena al llegar.
    _subjects =
        ordenados.map(StudentSubjectModel.desdeCurso).toList(growable: false);
    _cargando = false;
    _error = null;
    notifyListeners();
    await _cargarAsistencia(ordenados);
  }

  /// Relee la asistencia de los cursos que ya están en pantalla. La lista de
  /// cursos cambia poco; la asistencia cambia cada vez que el docente pasa
  /// lista, así que hay que poder volver a pedirla sin reiniciar la app.
  Future<void> refrescar() =>
      _cursos.isEmpty ? Future.value() : _cargarAsistencia(_cursos);

  Future<void> _cargarAsistencia(List<Curso> cursos) async {
    final claves = _claves;
    try {
      final resumenes = await Future.wait(
        cursos.map((c) => _servicio.resumenAsistencia(c.id, claves)),
      );
      // Otra emisión pudo reemplazar la lista mientras se leía la asistencia.
      if (!identical(claves, _claves)) return;
      _subjects = [
        for (var i = 0; i < cursos.length; i++)
          StudentSubjectModel.desdeCurso(cursos[i], asistencia: resumenes[i]),
      ];
      notifyListeners();
    } on CursoException catch (e) {
      _error = e.mensaje;
      notifyListeners();
    }
  }

  /// Escucha el llamado abierto de cada materia, y deja de escuchar las que
  /// ya no están en la lista.
  void _vigilarLlamados(List<Curso> cursos) {
    final ids = cursos.map((c) => c.id).toSet();
    for (final id in _llamados.keys.toList()) {
      if (ids.contains(id)) continue;
      _llamados.remove(id)!.cancel();
      _abiertos.remove(id);
    }
    for (final curso in cursos) {
      if (_llamados.containsKey(curso.id)) continue;
      _llamados[curso.id] = _servicio.llamadosAbiertos(curso.id).listen(
            (abiertos) => _alCambiarElLlamado(curso.id, abiertos),
            // Que falle esta consulta solo apaga el botón; el portal sigue.
            onError: (Object _) => _alCambiarElLlamado(curso.id, const []),
          );
    }
  }

  void _alCambiarElLlamado(String cursoId, List<Sesion> abiertos) {
    final ahora = DateTime.now();
    Sesion? vigente;
    for (final sesion in abiertos) {
      if (sesion.admiteAsistencia(ahora)) {
        vigente = sesion;
        break;
      }
    }
    if (vigente == null) {
      _abiertos.remove(cursoId);
    } else {
      _abiertos[cursoId] = vigente;
    }
    _programarExpiracion();
    notifyListeners();
  }

  void _programarExpiracion() {
    _expira?.cancel();
    final vigente = llamadoVigente;
    if (vigente == null) return;
    _expira = Timer(vigente.$2.restante(DateTime.now()), () {
      _programarExpiracion();
      notifyListeners();
    });
  }

  void _olvidarLlamados() {
    _expira?.cancel();
    _expira = null;
    for (final sub in _llamados.values) {
      sub.cancel();
    }
    _llamados.clear();
    _abiertos.clear();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _olvidarLlamados();
    super.dispose();
  }
}
