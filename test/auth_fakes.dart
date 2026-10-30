import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/services/auth_service.dart';
import 'package:smart_check/services/chaira_service.dart';
import 'package:smart_check/services/perfil_service.dart';

import 'chaira_fixtures.dart';

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
  Future<String?> signInWithEmailPassword(String email, String password) async {
    if (cuentas[email] != password) return 'Credenciales incorrectas.';
    _actual = FakeUser('uid-$email', email);
    return null;
  }

  @override
  Future<String?> registerWithEmailPassword(String email, String password) async {
    if (cuentas.containsKey(email)) return 'Ya existe una cuenta con ese correo.';
    cuentas[email] = password;
    _actual = FakeUser('uid-$email', email);
    return null;
  }

  @override
  Future<void> signOut() async => _actual = null;
}

/// Firestore en memoria.
class FakePerfilService extends Fake implements PerfilService {
  final perfiles = <String, UsuarioPerfil>{};
  final historial = <String, List<VinculoDispositivo>>{};
  PerfilException? fallo;

  /// La hora que pondría el servidor al vincular un celular.
  DateTime horaDelServidor = DateTime(2026, 1, 1, 8);

  @override
  Future<UsuarioPerfil?> obtener(String uid) async {
    if (fallo != null) throw fallo!;
    return perfiles[uid];
  }

  @override
  Future<void> guardar(UsuarioPerfil perfil) async {
    if (fallo != null) throw fallo!;
    perfiles[perfil.uid] = perfil;
  }

  @override
  Future<DateTime> vincularDispositivo(String uid, String dispositivoId) async {
    if (fallo != null) throw fallo!;
    final perfil = perfiles[uid];
    if (perfil == null) throw const PerfilException('No existe ese perfil.');
    historial.putIfAbsent(uid, () => []).insert(
          0,
          VinculoDispositivo(
            dispositivoId: dispositivoId,
            desde: horaDelServidor,
            anterior: perfil.dispositivoId,
          ),
        );
    perfiles[uid] = perfil.conDispositivo(dispositivoId, horaDelServidor);
    return horaDelServidor;
  }

  @override
  Future<List<VinculoDispositivo>> historialDeDispositivos(String uid) async {
    if (fallo != null) throw fallo!;
    return historial[uid] ?? const [];
  }
}

/// Chairá simulado: siempre encuentra a "ANA MARÍA PÉREZ GÓMEZ" con [tipo].
ChairaService chairaFalso({String tipo = 'ESTUDIANTE'}) => ChairaService(
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response('', 404);
        return http.Response.bytes(
          utf8.encode(respuestaExito(tipo: tipo)),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

UsuarioPerfil perfilDe(String email, String nombre, List<String> roles) =>
    UsuarioPerfil(
      uid: 'uid-$email',
      email: email,
      nombre: nombre,
      cedula: '1117000001',
      programa: 'INGENIERÍA DE SISTEMAS',
      tipoUsuario: roles.contains(Rol.docente) ? 'DOCENTE' : 'ESTUDIANTE',
      roles: roles,
    );
