import 'dart:async';

import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../models/inscrito_model.dart';
import '../models/sesion_model.dart';
import '../services/ble_service.dart';
import '../services/curso_service.dart';
import '../services/ubicacion_service.dart';

/// Un inscrito tal como lo ve el radar: si ya está marcado y con qué señal.
class InscritoEnRadar {
  final Inscrito inscrito;
  final Asistencia? asistencia;

  /// Fuerza de la última señal BLE, o null si todavía no se le ha oído.
  final int? rssi;

  const InscritoEnRadar(this.inscrito, this.asistencia, this.rssi);

  bool get detectado => asistencia != null;
}

/// ViewModel del radar del docente: abre la sesión de la clase, escucha las
/// balizas de los estudiantes y escribe la asistencia.
///
/// La asistencia solo se puede registrar si se cumplen las tres condiciones
/// que pidió el docente: estar en el horario de la clase, estar dentro de la
/// geocerca del aula, y que el celular del estudiante se oiga por BLE.
class RadarViewModel extends ChangeNotifier {
  /// Pasados estos minutos desde que arranca la clase, se marca "tarde".
  static const minutosParaTarde = 15;

  final CursoService _cursos;
  final BleService _ble;
  final UbicacionService _ubicacion;

  RadarViewModel({
    CursoService? cursos,
    BleService? ble,
    UbicacionService? ubicacion,
  })  : _cursos = cursos ?? CursoService(),
        _ble = ble ?? BleService(),
        _ubicacion = ubicacion ?? UbicacionService();

  StreamSubscription<BalizaDetectada>? _suscripcion;

  Curso? _curso;
  Sesion? _sesion;
  List<Inscrito> _inscritos = const [];
  final _porHuella = <int, String>{};
  final _asistencias = <String, Asistencia>{};
  final _rssi = <String, int>{};

  bool _ocupado = false;
  bool _escaneando = false;
  String? _error;

  Curso? get curso => _curso;
  Sesion? get sesion => _sesion;
  bool get ocupado => _ocupado;
  bool get escaneando => _escaneando;
  String? get error => _error;
  int get totalInscritos => _inscritos.length;
  int get detectados => _asistencias.length;
  int get faltantes => _inscritos.length - _asistencias.length;

  List<InscritoEnRadar> get lista {
    final lista = _inscritos
        .map((i) => InscritoEnRadar(i, _asistencias[i.clave], _rssi[i.clave]))
        .toList();
    // Los recién detectados arriba, y entre los que faltan por nombre.
    lista.sort((a, b) {
      if (a.detectado != b.detectado) return a.detectado ? -1 : 1;
      if (a.detectado) {
        return b.asistencia!.hora.compareTo(a.asistencia!.hora);
      }
      return a.inscrito.nombre.compareTo(b.inscrito.nombre);
    });
    return lista;
  }

  /// Abre la sesión de la clase de ahora y empieza a escuchar. Devuelve false
  /// si no se pudo (el motivo queda en [error]).
  Future<bool> iniciar(Curso curso, String docenteUid) async {
    if (_escaneando) return true;
    _curso = curso;
    _ocupado = true;
    _error = null;
    notifyListeners();
    try {
      final ahora = DateTime.now();
      final bloque = curso.horarioEn(ahora);
      if (bloque == null) {
        throw const _RadarException(
          'Fuera del horario de la clase. El radar solo se abre durante el '
          'bloque asignado al curso.',
        );
      }
      await _comprobarGeocerca(curso);

      _inscritos = await _cursos.inscritos(curso.id).first;
      _porHuella
        ..clear()
        ..addEntries(
          _inscritos.map((i) => MapEntry(BleService.huellaDe(i.clave), i.clave)),
        );

      _sesion = await _sesionDeLaClase(curso, bloque, ahora);
      await _cargarAsistencias(curso.id, _sesion!.id);

      _suscripcion = _ble.escanear().listen(
        _alOirBaliza,
        onError: (Object e) {
          _error = e.toString();
          _escaneando = false;
          notifyListeners();
        },
      );
      _escaneando = true;
      return true;
    } on _RadarException catch (e) {
      _error = e.mensaje;
      return false;
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
      _ocupado = false;
      notifyListeners();
    }
  }

  Future<void> _comprobarGeocerca(Curso curso) async {
    final geocerca = curso.geocerca;
    if (geocerca == null) return;
    final posicion = await _ubicacion.posicionActual();
    if (!geocerca.contiene(posicion.latitude, posicion.longitude)) {
      final metros =
          geocerca.distanciaA(posicion.latitude, posicion.longitude).round();
      throw _RadarException(
        'Estás a $metros m del aula. Acércate para abrir el radar.',
      );
    }
  }

  /// Reusa la sesión que ya esté abierta para esta clase; si no hay, la crea.
  Future<Sesion> _sesionDeLaClase(
    Curso curso,
    Horario bloque,
    DateTime ahora,
  ) async {
    final inicio = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      bloque.inicioMinutos ~/ 60,
      bloque.inicioMinutos % 60,
    );
    final fin = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      bloque.finMinutos ~/ 60,
      bloque.finMinutos % 60,
    );
    final existentes = await _cursos.sesiones(curso.id).first;
    for (final s in existentes) {
      if (s.inicio != inicio) continue;
      // La franja ya tiene sesión. Si el docente la había cerrado se intenta
      // reabrir la misma, para no partir la clase en dos.
      if (s.abierta) return s;
      try {
        await _cursos.reabrirSesion(curso.id, s.id);
        return Sesion(id: s.id, inicio: s.inicio, fin: s.fin);
      } on CursoException {
        // Las reglas pueden prohibir reabrir. Entonces se abre otra y la
        // asistencia las junta, porque cuenta por franja y no por sesión.
        break;
      }
    }
    final nueva = Sesion(inicio: inicio, fin: fin);
    final id = await _cursos.abrirSesion(curso.id, nueva);
    return Sesion(id: id, inicio: inicio, fin: fin);
  }

  Future<void> _cargarAsistencias(String cursoId, String sesionId) async {
    final ya = await _cursos.asistencias(cursoId, sesionId).first;
    _asistencias
      ..clear()
      ..addEntries(ya.map((a) => MapEntry(a.claveInscrito, a)));
  }

  void _alOirBaliza(BalizaDetectada baliza) {
    final clave = _porHuella[baliza.huella];
    if (clave == null) return;
    _rssi[clave] = baliza.rssi;
    if (_asistencias.containsKey(clave)) {
      notifyListeners();
      return;
    }
    _registrar(clave, MetodoAsistencia.ble);
  }

  /// Marca a mano a quien el radar no oyó.
  Future<bool> marcarManual(Inscrito inscrito, {bool presente = true}) async {
    return _registrar(
      inscrito.clave,
      MetodoAsistencia.manual,
      forzarEstado: presente ? null : EstadoAsistencia.ausente,
    );
  }

  Future<bool> _registrar(
    String clave,
    String metodo, {
    String? forzarEstado,
  }) async {
    final curso = _curso;
    final sesion = _sesion;
    if (curso == null || sesion == null) return false;
    final ahora = DateTime.now();
    final tarde = ahora.difference(sesion.inicio).inMinutes >= minutosParaTarde;
    final asistencia = Asistencia(
      claveInscrito: clave,
      estado: forzarEstado ??
          (tarde ? EstadoAsistencia.tarde : EstadoAsistencia.presente),
      metodo: metodo,
      hora: ahora,
      registradoPor: curso.docenteUid,
    );
    // Se pinta de una vez y se corrige si Firestore la rechaza.
    _asistencias[clave] = asistencia;
    notifyListeners();
    try {
      await _cursos.registrarAsistencia(curso.id, sesion.id, asistencia);
      return true;
    } on CursoException catch (e) {
      _asistencias.remove(clave);
      _error = e.mensaje;
      notifyListeners();
      return false;
    }
  }

  /// Cierra la clase: deja de escuchar y marca la sesión como cerrada, que es
  /// lo que la hace contar en los porcentajes de asistencia.
  Future<void> detener({bool cerrarSesion = true}) async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _ble.detenerEscaneo();
    _escaneando = false;
    final curso = _curso;
    final sesion = _sesion;
    if (cerrarSesion && curso != null && sesion != null) {
      try {
        await _cursos.cerrarSesion(curso.id, sesion.id);
        _sesion = null;
      } on CursoException catch (e) {
        _error = e.mensaje;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _ble.detenerEscaneo();
    super.dispose();
  }
}

class _RadarException implements Exception {
  final String mensaje;
  const _RadarException(this.mensaje);
}
