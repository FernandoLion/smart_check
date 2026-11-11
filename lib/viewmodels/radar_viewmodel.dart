import 'dart:async';

import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../models/inscrito_model.dart';
import '../models/presencia_model.dart';
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

  /// Ya tiene marca en este llamado, sea presente o ausente.
  bool get registrado => asistencia != null;

  /// Cuenta como presente: lo oyó el radar o el docente lo marcó presente.
  /// Uno marcado ausente a mano tiene marca, pero no está.
  bool get detectado => asistencia?.cuentaComoAsistio ?? false;
}

/// ViewModel del radar del docente: abre el llamado de asistencia de la clase
/// de ahora, escucha las balizas de los estudiantes y escribe la asistencia.
///
/// La asistencia solo se registra si se cumplen las condiciones que pidió el
/// docente: estar en el horario y el día de la clase, estar dentro de la
/// geocerca del aula, que el celular del estudiante se oiga por BLE, y que
/// todo eso ocurra dentro de la ventana del llamado.
class RadarViewModel extends ChangeNotifier {
  /// Si al bloque de clase le queda menos que esto, no se abre el llamado:
  /// una ventana de treinta segundos solo alcanza para confundir.
  static const minimoLlamado = Duration(minutes: 2);

  final CursoService _cursos;
  final BleService _ble;
  final UbicacionService _ubicacion;

  /// Inyectable para poder probar la ventana del llamado sin esperar diez
  /// minutos de reloj de verdad.
  final DateTime Function() _ahora;

  RadarViewModel({
    CursoService? cursos,
    BleService? ble,
    UbicacionService? ubicacion,
    DateTime Function()? reloj,
  })  : _cursos = cursos ?? CursoService(),
        _ble = ble ?? BleService(),
        _ubicacion = ubicacion ?? UbicacionService(),
        _ahora = reloj ?? DateTime.now;

  StreamSubscription<BalizaDetectada>? _suscripcion;

  /// Cierra el llamado cuando se acaba la ventana, para que el docente no
  /// tenga que estar pendiente del reloj.
  Timer? _cierre;

  Curso? _curso;
  Sesion? _sesion;
  List<Inscrito> _inscritos = const [];
  final _porHuella = <int, String>{};
  final _asistencias = <String, Asistencia>{};
  final _rssi = <String, int>{};

  /// Cada cuánto se reintenta registrar a quien se oye sin firma. El radar
  /// recibe varios anuncios por segundo de cada celular: reintentar con cada
  /// uno serían cientos de escrituras rechazadas por minuto con un salón
  /// lleno, y la firma, cuando llega, no tiene prisa de un segundo.
  static const reintentoSinFirma = Duration(seconds: 3);

  /// A quién se oyó por BLE pero el servidor todavía no deja registrar
  /// porque no ha firmado su presencia, y cuándo se le rechazó por última
  /// vez. Se reintenta con sus anuncios, cada [reintentoSinFirma].
  final _sinFirma = <String, DateTime>{};

  /// Si a este inscrito se le oye pero aún falta su firma.
  bool esperandoFirma(String clave) => _sinFirma.containsKey(clave);

  /// Las firmas del llamado, por clave. Dicen, entre otras cosas, si el
  /// estudiante registró su rostro en este mismo momento.
  StreamSubscription<List<Presencia>>? _subFirmas;
  var _firmas = <String, Presencia>{};

  /// Si este inscrito registró su rostro hoy (no tenía referencia en su
  /// celular): no es fraude por sí solo, pero el docente debería mirarlo.
  bool rostroRecienRegistrado(String clave) =>
      _firmas[clave]?.rostroRecienEnrolado ?? false;

  /// Si este inscrito firmó desde un celular que ató a su cuenta hace menos
  /// de un día. Desde que cambiar de celular no tiene espera, es la señal que
  /// le queda al docente para notar una cuenta que va de teléfono en
  /// teléfono. Tampoco es fraude por sí sola: cambiar de celular es normal.
  bool celularRecienVinculado(String clave) =>
      _firmas[clave]?.celularReciente(_ahora()) ?? false;

  /// A cuántos metros del aula dijo estar al firmar, con el margen del GPS,
  /// o null si el curso no tiene geocerca o aún no firma.
  ({int distancia, int precision})? ubicacionAlFirmar(String clave) {
    final firma = _firmas[clave];
    final distancia = firma?.distanciaAula;
    final precision = firma?.precisionGps;
    if (distancia == null || precision == null) return null;
    return (distancia: distancia, precision: precision);
  }

  bool _ocupado = false;
  bool _escaneando = false;
  String? _error;

  Curso? get curso => _curso;
  Sesion? get sesion => _sesion;
  bool get ocupado => _ocupado;
  bool get escaneando => _escaneando;
  String? get error => _error;
  int get totalInscritos => _inscritos.length;
  int get detectados =>
      _asistencias.values.where((a) => a.cuentaComoAsistio).length;
  int get faltantes => _inscritos.length - detectados;

  /// Lo que queda de ventana del llamado, para la cuenta atrás de la
  /// pantalla.
  Duration? get restanteDelLlamado => _sesion?.restante(_ahora());

  /// La ventana ya pasó: desde aquí solo se puede marcar a mano.
  bool get llamadoVencido {
    final sesion = _sesion;
    return sesion != null && sesion.vencida(_ahora());
  }

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

  /// El acta del llamado en CSV, como está en este momento: cada inscrito
  /// con su estado, cómo se marcó y a qué hora.
  String actaEnCsv() {
    String dos(int n) => n.toString().padLeft(2, '0');
    String celda(String v) =>
        v.contains(RegExp('[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final filas = [...lista]
      ..sort((a, b) => a.inscrito.nombre.compareTo(b.inscrito.nombre));
    return [
      'Estudiante;Identificación;Estado;Cómo se marcó;Hora',
      for (final f in filas)
        [
          f.inscrito.nombre,
          f.inscrito.cedula ?? f.inscrito.email ?? '',
          switch (f.asistencia?.estado) {
            null => 'Sin registro',
            EstadoAsistencia.ausente => 'Ausente',
            EstadoAsistencia.tarde => 'Tarde',
            _ => 'Presente',
          },
          switch (f.asistencia?.metodo) {
            null => '',
            MetodoAsistencia.ble => 'Bluetooth',
            _ => 'A mano',
          },
          f.asistencia == null
              ? ''
              : '${dos(f.asistencia!.hora.hour)}:${dos(f.asistencia!.hora.minute)}',
        ].map(celda).join(';'),
    ].join('\n');
  }

  /// Abre el llamado de la clase de ahora y empieza a escuchar. Devuelve
  /// false si no se pudo (el motivo queda en [error]).
  Future<bool> iniciar(Curso curso, String docenteUid) async {
    if (_escaneando) return true;
    _curso = curso;
    _ocupado = true;
    _error = null;
    notifyListeners();
    try {
      final ahora = _ahora();
      final bloque = curso.horarioEn(ahora);
      if (bloque == null) {
        throw const _RadarException(
          'Fuera del horario de la clase. El radar solo se abre durante el '
          'bloque asignado al curso.',
        );
      }
      await _comprobarGeocerca(curso);

      _inscritos = await _cursos.inscritos(curso.id).first;
      // Cada inscrito se indexa por cédula y por correo: el docente pudo
      // inscribirlo por uno y el estudiante emitir con el otro.
      _porHuella.clear();
      for (final inscrito in _inscritos) {
        for (final clave in inscrito.claves) {
          _porHuella[BleService.huellaDe(clave)] = inscrito.clave;
        }
      }

      _sesion = await _sesionDeLaClase(curso, bloque, ahora);
      await _cargarAsistencias(curso.id, _sesion!);
      _programarCierre(_sesion!);
      _vigilarFirmas(curso.id, _sesion!.id);

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
    final aula = await comprobarAula(_ubicacion, curso.geocerca);
    if (aula != null && !aula.dentro) {
      throw _RadarException('${aula.estasA}. Acércate para abrir el radar.');
    }
  }

  /// Reusa el llamado que siga vigente para esta clase; si no hay, abre otro.
  Future<Sesion> _sesionDeLaClase(
    Curso curso,
    Horario bloque,
    DateTime ahora,
  ) async {
    final bloqueInicio = _conHora(ahora, bloque.inicioMinutos);
    final bloqueFin = _conHora(ahora, bloque.finMinutos);
    if (bloqueFin.difference(ahora) < minimoLlamado) {
      throw _RadarException(
        'A la clase le quedan menos de ${minimoLlamado.inMinutes} minutos. '
        'Pasa la lista a mano.',
      );
    }
    for (final abierto in await _cursos.llamadosAbiertos(curso.id).first) {
      // El docente volvió al radar sin que se cerrara la ventana: es el mismo
      // llamado, no uno nuevo.
      if (!abierto.vencida(ahora) && abierto.franja == bloqueInicio) {
        return abierto;
      }
      // Quedó abierto de un llamado anterior porque se le murió la app. Se
      // cierra para que nunca haya dos abiertos a la vez: el celular del
      // estudiante decide si puede marcar mirando justo eso.
      await _cursos.cerrarSesion(curso.id, abierto.id);
    }
    final nuevo = Sesion.llamado(
      ahora: ahora,
      bloqueInicio: bloqueInicio,
      bloqueFin: bloqueFin,
    );
    return nuevo.copyWith(id: await _cursos.abrirSesion(curso.id, nuevo));
  }

  /// La hora [minutos] del mismo día que [dia]: así el horario del curso, que
  /// se guarda como "HH:mm", se convierte en una fecha concreta.
  static DateTime _conHora(DateTime dia, int minutos) =>
      DateTime(dia.year, dia.month, dia.day, minutos ~/ 60, minutos % 60);

  /// Lo ya marcado en esta clase: en este llamado y en los anteriores del
  /// mismo bloque, porque el docente pudo cerrar el radar y volver a abrirlo.
  /// Así quien ya marcó sale marcado, no se le vuelve a registrar y el
  /// llamado manual no pregunta por él.
  Future<void> _cargarAsistencias(String cursoId, Sesion sesion) async {
    final ids = {
      sesion.id,
      for (final s in await _cursos.sesiones(cursoId).first)
        if (s.franja == sesion.franja) s.id,
    };
    final porSesion =
        await _cursos.asistenciasDeSesiones(cursoId, ids.toList());
    final porClave = <String, List<Asistencia>>{};
    for (final marcas in porSesion.values) {
      for (final a in marcas) {
        (porClave[a.claveInscrito] ??= []).add(a);
      }
    }
    _asistencias
      ..clear()
      ..addEntries([
        for (final MapEntry(key: clave, value: marcas) in porClave.entries)
          MapEntry(clave, CursoService.marcaQueCuenta(marcas)!),
      ]);
  }

  void _vigilarFirmas(String cursoId, String sesionId) {
    _subFirmas?.cancel();
    _subFirmas = _cursos.presencias(cursoId, sesionId).listen(
      (firmas) {
        _firmas = {for (final f in firmas) f.claveInscrito: f};
        notifyListeners();
      },
      // Es información extra para el docente: si no llega, el radar sigue.
      onError: (Object _) {},
    );
  }

  void _alOirBaliza(BalizaDetectada baliza) {
    final clave = _porHuella[baliza.huella];
    if (clave == null) return;
    _rssi[clave] = baliza.rssi;
    final rechazo = _sinFirma[clave];
    if (_asistencias.containsKey(clave) ||
        (rechazo != null &&
            _ahora().difference(rechazo) < reintentoSinFirma)) {
      notifyListeners();
      return;
    }
    _registrar(clave, MetodoAsistencia.ble);
  }

  /// Marca a mano a quien el radar no oyó.
  /// [estado]: presente, ausente o justificada (no vino, con excusa).
  Future<bool> marcarManual(
    Inscrito inscrito, {
    String estado = EstadoAsistencia.presente,
  }) async {
    return _registrar(
      inscrito.clave,
      MetodoAsistencia.manual,
      forzarEstado: estado == EstadoAsistencia.presente ? null : estado,
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
    final ahora = _ahora();
    final asistencia = Asistencia(
      claveInscrito: clave,
      // Dentro de la ventana del llamado todos quedan presentes: la ventana
      // misma es el criterio de puntualidad. "Tarde" lo pone el docente a
      // mano si quiere matizarlo.
      estado: forzarEstado ?? EstadoAsistencia.presente,
      metodo: metodo,
      hora: ahora,
      registradoPor: curso.docenteUid,
    );
    // Se pinta de una vez y se corrige si Firestore la rechaza.
    _asistencias[clave] = asistencia;
    notifyListeners();
    try {
      await _cursos.registrarAsistencia(curso.id, sesion.id, asistencia);
      _sinFirma.remove(clave);
      return true;
    } on CursoException catch (e) {
      _asistencias.remove(clave);
      // Si el servidor rechaza una asistencia por BLE es, casi siempre,
      // porque el estudiante todavía no ha firmado su presencia: su celular
      // sigue anunciándose, así que el siguiente anuncio lo reintenta solo.
      // Sacarle un error al docente por eso sería ruido.
      if (metodo == MetodoAsistencia.ble && e.denegado) {
        _sinFirma[clave] = _ahora();
      } else {
        _error = e.mensaje;
      }
      notifyListeners();
      return false;
    }
  }

  void _programarCierre(Sesion sesion) {
    _cierre?.cancel();
    _cierre = Timer(sesion.restante(_ahora()), cerrarLlamado);
  }

  /// Se acabó la ventana: deja de escuchar balizas y cierra el llamado, pero
  /// se queda con la sesión en memoria. El llamado manual del docente se hace
  /// justo en este momento, y las reglas lo permiten también después de la
  /// ventana porque es una corrección suya.
  Future<void> cerrarLlamado() async {
    _cierre?.cancel();
    _cierre = null;
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _ble.detenerEscaneo();
    _escaneando = false;
    await _cerrarEnLaBase();
    notifyListeners();
  }

  /// Sale del radar: cierra el llamado y olvida la sesión.
  Future<void> detener({bool cerrarSesion = true}) async {
    _cierre?.cancel();
    _cierre = null;
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _ble.detenerEscaneo();
    _escaneando = false;
    if (cerrarSesion) {
      await _cerrarEnLaBase();
      await _subFirmas?.cancel();
      _subFirmas = null;
      _sesion = null;
    }
    notifyListeners();
  }

  /// Marca la sesión como cerrada, que es lo que la hace contar en los
  /// porcentajes de asistencia. Si ya estaba cerrada no escribe nada.
  Future<void> _cerrarEnLaBase() async {
    final curso = _curso;
    final sesion = _sesion;
    if (curso == null || sesion == null || !sesion.abierta) return;
    try {
      await _cursos.cerrarSesion(curso.id, sesion.id);
      _sesion = sesion.copyWith(abierta: false);
    } on CursoException catch (e) {
      _error = e.mensaje;
    }
  }

  @override
  void dispose() {
    _cierre?.cancel();
    _suscripcion?.cancel();
    _subFirmas?.cancel();
    _ble.detenerEscaneo();
    // Al salir de la pantalla se cierra el llamado igual que con el botón: una
    // ventana abierta sin nadie escuchando dejaría marcar a quien no está.
    final curso = _curso;
    final sesion = _sesion;
    if (curso != null && sesion != null && sesion.abierta) {
      _cursos.cerrarSesion(curso.id, sesion.id).ignore();
      _sesion = null;
    }
    super.dispose();
  }
}

class _RadarException implements Exception {
  final String mensaje;
  const _RadarException(this.mensaje);
}
