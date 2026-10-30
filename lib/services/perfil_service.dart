import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario_perfil_model.dart';

/// Error al leer o guardar un perfil, con un mensaje listo para mostrar.
class PerfilException implements Exception {
  final String mensaje;
  const PerfilException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Guarda y lee los perfiles de usuario en Firestore (`usuarios/{uid}`).
class PerfilService {
  static const _timeout = Duration(seconds: 15);

  // Se resuelve al usarse (Firebase puede no estar inicializado en los tests).
  CollectionReference<Map<String, dynamic>> get _usuarios =>
      FirebaseFirestore.instance.collection('usuarios');

  Future<UsuarioPerfil?> obtener(String uid) async {
    try {
      final doc = await _usuarios.doc(uid).get().timeout(_timeout);
      final data = doc.data();
      return data == null ? null : UsuarioPerfil.fromMap(doc.id, data);
    } catch (e) {
      throw PerfilException(_mensaje(e, 'leer tu perfil'));
    }
  }

  Future<void> guardar(UsuarioPerfil perfil) async {
    try {
      await _usuarios.doc(perfil.uid).set(perfil.toMap()).timeout(_timeout);
    } catch (e) {
      throw PerfilException(_mensaje(e, 'guardar tu perfil'));
    }
  }

  /// Ata [dispositivoId] a la cuenta y lo apunta en el historial, y devuelve
  /// la hora con la que quedó guardado.
  ///
  /// La hora la pone el servidor: las reglas exigen que `dispositivo_desde`
  /// sea `request.time`, porque si la pusiera el celular bastaría con
  /// adelantar el reloj para saltarse la espera entre cambios. Por eso
  /// también se relee del servidor y no de la caché, donde el valor aún
  /// sería una estimación local: esa hora tiene que coincidir **exacta** con
  /// la que después se firma en cada presencia.
  Future<DateTime> vincularDispositivo(String uid, String dispositivoId) async {
    try {
      final doc = _usuarios.doc(uid);
      final anterior = (await doc.get().timeout(_timeout))
          .data()?['dispositivo_id'] as String?;

      // En un lote, para que no pueda quedar el perfil cambiado sin su línea
      // en el historial.
      final lote = FirebaseFirestore.instance.batch();
      lote.update(doc, {
        'dispositivo_id': dispositivoId,
        'dispositivo_desde': FieldValue.serverTimestamp(),
      });
      lote.set(doc.collection('dispositivos').doc(), {
        'dispositivo_id': dispositivoId,
        'desde': FieldValue.serverTimestamp(),
        'anterior': anterior,
      });
      await lote.commit().timeout(_timeout);

      final fresco = await doc
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      final desde = (fresco.data()?['dispositivo_desde'] as Timestamp?)?.toDate();
      if (desde == null) {
        throw const PerfilException(
          'No se pudo vincular este celular: el servidor no guardó la fecha.',
        );
      }
      return desde;
    } on PerfilException {
      rethrow;
    } catch (e) {
      throw PerfilException(_mensaje(e, 'vincular este celular'));
    }
  }

  /// Los celulares que ha tenido esta cuenta, del más reciente al más viejo.
  Future<List<VinculoDispositivo>> historialDeDispositivos(String uid) async {
    try {
      final docs = await _usuarios
          .doc(uid)
          .collection('dispositivos')
          .orderBy('desde', descending: true)
          .get()
          .timeout(_timeout);
      return docs.docs
          .map((d) => VinculoDispositivo.fromMap(d.data()))
          .toList();
    } catch (e) {
      throw PerfilException(_mensaje(e, 'leer tus celulares'));
    }
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
