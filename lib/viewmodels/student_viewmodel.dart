import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asistencia_resumen.dart';
import '../models/curso_model.dart';
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

  List<StudentSubjectModel> _subjects = const [];
  bool _cargando = false;
  String? _error;

  List<StudentSubjectModel> get subjects => _subjects;
  bool get cargando => _cargando;
  String? get error => _error;

  String get currentPeriod => Curso.periodoActual();

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
    _claves = claves;
    _subjects = const [];
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
    // Se muestran los cursos de una vez y la asistencia se llena al llegar.
    _subjects =
        ordenados.map(StudentSubjectModel.desdeCurso).toList(growable: false);
    _cargando = false;
    _error = null;
    notifyListeners();

    final claves = _claves;
    try {
      final resumenes = await Future.wait(
        ordenados.map((c) => _servicio.resumenAsistencia(c.id, claves)),
      );
      // Otra emisión pudo reemplazar la lista mientras se leía la asistencia.
      if (!identical(claves, _claves)) return;
      _subjects = [
        for (var i = 0; i < ordenados.length; i++)
          StudentSubjectModel.desdeCurso(
            ordenados[i],
            asistencia: resumenes[i],
          ),
      ];
      notifyListeners();
    } on CursoException catch (e) {
      _error = e.mensaje;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
