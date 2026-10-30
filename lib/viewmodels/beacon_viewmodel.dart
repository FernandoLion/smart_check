import 'dart:async';

import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../models/sesion_model.dart';
import '../services/ble_service.dart';
import '../services/curso_service.dart';
import '../services/ubicacion_service.dart';

/// ViewModel del celular del estudiante mientras marca asistencia: busca el
/// llamado que el docente tenga abierto ahora, comprueba que esté en el aula
/// y se anuncia por BLE para que el celular del docente lo oiga.
class BeaconViewModel extends ChangeNotifier {
  final CursoService _cursos;
  final BleService _ble;
  final UbicacionService _ubicacion;

  BeaconViewModel({
    CursoService? cursos,
    BleService? ble,
    UbicacionService? ubicacion,
  })  : _cursos = cursos ?? CursoService(),
        _ble = ble ?? BleService(),
        _ubicacion = ubicacion ?? UbicacionService();

  Curso? _curso;
  Sesion? _sesion;
  bool _buscando = false;
  bool _anunciando = false;
  bool _vencida = false;
  String? _error;

  /// Deja de anunciar en cuanto se acaba la ventana del llamado.
  Timer? _ventana;

  Curso? get curso => _curso;
  Sesion? get sesion => _sesion;
  bool get buscando => _buscando;
  bool get anunciando => _anunciando;
  String? get error => _error;

  /// La ventana se cerró sola; no lo paró el estudiante.
  bool get ventanaVencida => _vencida;

  /// Lo que queda de llamado, para la cuenta atrás.
  Duration get restante => _sesion?.restante(DateTime.now()) ?? Duration.zero;

  /// Minutos que faltan para que se cierre el llamado.
  int get minutosRestantes => restante.inMinutes;

  /// Busca entre [cursos] uno con el llamado abierto ahora mismo y empieza a
  /// anunciar [clave]. Devuelve false si no hay llamado, si el estudiante no
  /// está en el aula o si falla el BLE.
  Future<bool> marcar(List<Curso> cursos, String clave) async {
    _buscando = true;
    _error = null;
    _vencida = false;
    notifyListeners();
    try {
      final abierto = await _buscarLlamadoAbierto(cursos);
      if (abierto == null) {
        _error = 'Ninguno de tus docentes tiene el llamado abierto ahora '
            'mismo. Espera a que inicie el radar.';
        return false;
      }
      // La ubicación se comprueba también en este celular, no solo en el del
      // docente: emitir la baliza desde la cafetería no es asistir a clase.
      final metros = await metrosFueraDelAula(_ubicacion, abierto.$1.geocerca);
      if (metros != null) {
        _error = 'Estás a $metros m del aula. Acércate para registrar tu '
            'asistencia.';
        return false;
      }
      _curso = abierto.$1;
      _sesion = abierto.$2;
      await _ble.anunciar(clave);
      _anunciando = true;
      _ventana = Timer(abierto.$2.restante(DateTime.now()), _alVencerLaVentana);
      return true;
    } on CursoException catch (e) {
      _error = e.mensaje;
      return false;
    } on UbicacionException catch (e) {
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

  Future<(Curso, Sesion)?> _buscarLlamadoAbierto(List<Curso> cursos) async {
    final ahora = DateTime.now();
    for (final curso in cursos) {
      for (final sesion in await _cursos.llamadosAbiertos(curso.id).first) {
        if (sesion.admiteAsistencia(ahora)) return (curso, sesion);
      }
    }
    return null;
  }

  /// Se acabó la ventana: se deja de emitir sin que el estudiante tenga que
  /// hacer nada. Si el docente no lo oyó, ya solo queda el llamado manual.
  Future<void> _alVencerLaVentana() async {
    await parar();
    _vencida = true;
    notifyListeners();
  }

  Future<void> parar() async {
    _ventana?.cancel();
    _ventana = null;
    await _ble.dejarDeAnunciar();
    _anunciando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ventana?.cancel();
    _ble.dejarDeAnunciar();
    super.dispose();
  }
}
