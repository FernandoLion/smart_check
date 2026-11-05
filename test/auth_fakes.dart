import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/services/auth_service.dart';
import 'package:smart_check/services/perfil_service.dart';

/// Servicios falsos en memoria: las pruebas no tocan el Firebase real.

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  FakeUser(this.uid, this.email);
}

/// Firebase Auth en memoria: correo -> contraseña.
class FakeAuthService extends Fake implements AuthService {
  final cuentas = <String, String>{};
  User? _actual;

  @override
  User? get currentUser => _actual;

  @override
  Future<User?> sesionGuardada() async => _actual;

  @override
  Future<String?> signInWithEmailPassword(String email, String password) async {
    if (cuentas[email] != password) return 'Credenciales incorrectas.';
    _actual = FakeUser('uid-$email', email);
    return null;
  }

  @override
  Future<void> signOut() async => _actual = null;
}

/// Firestore en memoria: uid -> perfil.
class FakePerfilService extends Fake implements PerfilService {
  final perfiles = <String, UsuarioPerfil>{};
  PerfilException? fallo;

  @override
  Future<UsuarioPerfil?> obtener(String uid) async {
    if (fallo != null) throw fallo!;
    return perfiles[uid];
  }
}

UsuarioPerfil perfilDe(String email, String nombre, List<String> roles) =>
    UsuarioPerfil(uid: 'uid-$email', email: email, nombre: nombre, roles: roles);
