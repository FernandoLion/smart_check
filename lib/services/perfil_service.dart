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

/// Lee y guarda los perfiles de usuario en Firestore (`usuarios/{uid}`).
class PerfilService {
  /// Si Firestore no responde en este tiempo, se da por fallido.
  static const _timeout = Duration(seconds: 15);

  // Se resuelve al usarse (Firebase puede no estar inicializado en los tests).
  CollectionReference<Map<String, dynamic>> get _usuarios =>
      FirebaseFirestore.instance.collection('usuarios');

  /// El perfil del usuario [uid], o null si la cuenta no tiene perfil.
  Future<UsuarioPerfil?> obtener(String uid) async {
    try {
      final doc = await _usuarios.doc(uid).get().timeout(_timeout);
      final data = doc.data();
      return data == null ? null : UsuarioPerfil.fromMap(doc.id, data);
    } catch (e) {
      throw PerfilException(_mensaje(e, 'leer tu perfil'));
    }
  }

  /// Guarda el perfil en `usuarios/{uid}` (al registrarse).
  Future<void> guardar(UsuarioPerfil perfil) async {
    try {
      await _usuarios.doc(perfil.uid).set(perfil.toMap()).timeout(_timeout);
    } catch (e) {
      throw PerfilException(_mensaje(e, 'guardar tu perfil'));
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
