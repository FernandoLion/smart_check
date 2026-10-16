import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Se resuelve al usarse, no al construir el servicio (Firebase puede no
  // estar inicializado todavía, p. ej. en los tests).
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // null significa éxito
    } on FirebaseAuthException catch (e) {
      final usuario = email.split('@').first;
      if (e.code == 'user-not-found') {
        return 'No existe una cuenta con el usuario $usuario.';
      } else if (e.code == 'wrong-password') {
        return 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        return 'El usuario $usuario no es válido.';
      } else if (e.code == 'invalid-credential') {
        // Con la protección contra enumeración de correos de Firebase activa,
        // usuario inexistente y contraseña incorrecta llegan con este código.
        return 'Usuario o contraseña incorrectos.';
      } else if (e.code == 'too-many-requests') {
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      } else if (e.code == 'network-request-failed') {
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
      } else if (e.code == 'user-disabled') {
        return 'Esta cuenta está deshabilitada.';
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
        return 'Ya existe una cuenta con el usuario ${email.split('@').first}.';
      } else if (e.code == 'invalid-email') {
        return 'El usuario no es válido.';
      } else if (e.code == 'network-request-failed') {
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
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
        return 'No existe una cuenta con el usuario ${email.split('@').first}.';
      } else if (e.code == 'invalid-email') {
        return 'El usuario no es válido.';
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