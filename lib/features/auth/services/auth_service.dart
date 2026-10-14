import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // null significa éxito
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No se encontró un usuario con ese correo.';
      } else if (e.code == 'wrong-password') {
        return 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        return 'El formato del correo es inválido.';
      } else if (e.code == 'invalid-credential') {
        return 'Credenciales incorrectas.';
      }
      return e.message ?? 'Ocurrió un error al iniciar sesión.';
    } catch (e) {
      return 'Error desconocido: ${e.toString()}';
    }
  }

  Future<String?> registerWithEmailPassword(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'La contraseña es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        return 'Ya existe una cuenta con ese correo.';
      } else if (e.code == 'invalid-email') {
        return 'El formato del correo es inválido.';
      }
      return e.message ?? 'Ocurrió un error al registrarse.';
    } catch (e) {
      return 'Error desconocido: ${e.toString()}';
    }
  }

  Future<String?> recoverPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No hay un usuario registrado con este correo.';
      } else if (e.code == 'invalid-email') {
        return 'El formato del correo es inválido.';
      }
      return e.message ?? 'Ocurrió un error al intentar enviar el correo de recuperación.';
    } catch (e) {
      return 'Error desconocido: ${e.toString()}';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
