import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../models/sesion_model.dart';
import '../services/ble_service.dart';
import '../services/curso_service.dart';

/// ViewModel del celular del estudiante mientras marca asistencia: busca la
/// clase que el docente tenga abierta ahora y se anuncia por BLE para que el
/// celular del docente lo oiga.
class BeaconViewModel extends ChangeNotifier {
  final CursoService _cursos;
  final BleService _ble;

  BeaconViewModel({CursoService? cursos, BleService? ble})
      : _cursos = cursos ?? CursoService(),
        _ble = ble ?? BleService();

  Curso? _curso;
  Sesion? _sesion;
  bool _buscando = false;
  bool _anunciando = false;
  String? _error;

  Curso? get curso => _curso;
  Sesion? get sesion => _sesion;
  bool get buscando => _buscando;
  bool get anunciando => _anunciando;
  String? get error => _error;

  /// Minutos que faltan para que se cierre la franja de la clase.
  int get minutosRestantes {
    final sesion = _sesion;
    if (sesion == null) return 0;
    final restan = sesion.fin.difference(DateTime.now()).inMinutes;
    return restan < 0 ? 0 : restan;
  }

  /// Busca entre [cursos] uno con sesión abierta ahora mismo y empieza a
  /// anunciar [clave]. Devuelve false si no hay clase abierta o falla el BLE.
  Future<bool> marcar(List<Curso> cursos, String clave) async {
    _buscando = true;
    _error = null;
    notifyListeners();
    try {
      final abierta = await _buscarClaseAbierta(cursos);
      if (abierta == null) {
        _error = 'Ninguno de tus docentes tiene la clase abierta ahora '
            'mismo. Espera a que inicie el radar.';
        return false;
      }
      _curso = abierta.$1;
      _sesion = abierta.$2;
      await _ble.anunciar(clave);
      _anunciando = true;
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      return false;
    } on BleException catch (e) {
      _error = e.mensaje;
      return false;
    } finally {
      _buscando = false;
      notifyListeners();
    }
  }

  Future<(Curso, Sesion)?> _buscarClaseAbierta(List<Curso> cursos) async {
    final ahora = DateTime.now();
    for (final curso in cursos) {
      final sesiones = await _cursos.sesiones(curso.id).first;
      for (final sesion in sesiones) {
        if (sesion.admiteAsistencia(ahora)) return (curso, sesion);
      }
    }
    return null;
  }

  Future<void> parar() async {
    await _ble.dejarDeAnunciar();
    _anunciando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ble.dejarDeAnunciar();
    super.dispose();
  }
}
