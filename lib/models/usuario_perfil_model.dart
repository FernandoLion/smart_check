import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'verificacion_result_model.dart';

/// Roles con los que un usuario puede entrar a la app.
class Rol {
  static const docente = 'docente';
  static const estudiante = 'estudiante';
}

/// Un celular atado a una cuenta, tal como quedó escrito en el historial
/// (`usuarios/{uid}/dispositivos`), que es de solo añadir: cada cambio deja
/// su rastro y no se puede corregir ni borrar.
class VinculoDispositivo {
  final String dispositivoId;
  final DateTime desde;

  /// El celular que estaba atado antes, o null si este fue el primero.
  final String? anterior;

  const VinculoDispositivo({
    required this.dispositivoId,
    required this.desde,
    this.anterior,
  });

  factory VinculoDispositivo.fromMap(Map<String, dynamic> map) =>
      VinculoDispositivo(
        dispositivoId: map['dispositivo_id'] as String? ?? '',
        desde: (map['desde'] as Timestamp?)?.toDate() ?? DateTime(0),
        anterior: map['anterior'] as String?,
      );
}

/// Modelo (M de MVVM) del perfil del usuario registrado.
///
/// Se guarda en Firestore (`usuarios/{uid}`) al registrarse, con los datos
/// verificados en Chairá, y se lee al iniciar sesión para saber quién es el
/// usuario y con qué roles puede entrar.
class UsuarioPerfil {
  final String uid;
  final String email;
  final String nombre;
  final String? cedula;
  final String? programa;
  final String? tipoUsuario;
  final String? fotoUrl;
  final List<String> roles;

  /// El celular con el que este usuario marca asistencia, y desde cuándo.
  ///
  /// Son los únicos campos del perfil que se pueden cambiar después de
  /// registrarse, y solo desde la propia cuenta: las reglas los usan para
  /// comprobar que la firma de asistencia salió del celular vinculado. Van
  /// nulos en los perfiles creados antes de la vinculación.
  final String? dispositivoId;
  final DateTime? dispositivoDesde;

  /// Lo que hay que esperar para poder vincular otro celular. Sin esto,
  /// turnarse un teléfono entre varios sería tan fácil como volver a pulsar
  /// el botón; con esto, quien pierda el suyo antes de tiempo lo marca el
  /// docente a mano.
  static const esperaEntreDispositivos = Duration(days: 7);

  const UsuarioPerfil({
    required this.uid,
    required this.email,
    required this.nombre,
    this.cedula,
    this.programa,
    this.tipoUsuario,
    this.fotoUrl,
    required this.roles,
    this.dispositivoId,
    this.dispositivoDesde,
  });

  /// Crea el perfil a partir de la verificación en Chairá. Los docentes son
  /// también estudiantes solo si activaron "También curso materias".
  factory UsuarioPerfil.desdeVerificacion({
    required String uid,
    required String email,
    required VerificacionResult verificacion,
    bool tambienEstudiante = false,
  }) {
    return UsuarioPerfil(
      uid: uid,
      email: email,
      nombre: verificacion.nombre ?? '',
      cedula: verificacion.cedula ?? verificacion.documentoConsultado,
      programa: verificacion.programa,
      tipoUsuario: verificacion.tipoUsuario,
      fotoUrl: verificacion.fotoUrl,
      roles: verificacion.esDocente
          ? [Rol.docente, if (tambienEstudiante) Rol.estudiante]
          : [Rol.estudiante],
    );
  }

  factory UsuarioPerfil.fromMap(String uid, Map<String, dynamic> map) {
    return UsuarioPerfil(
      uid: uid,
      email: map['email'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      cedula: map['cedula'] as String?,
      programa: map['programa'] as String?,
      tipoUsuario: map['tipo_usuario'] as String?,
      fotoUrl: map['foto_url'] as String?,
      roles: List<String>.from(map['roles'] as List? ?? const []),
      dispositivoId: map['dispositivo_id'] as String?,
      dispositivoDesde: (map['dispositivo_desde'] as Timestamp?)?.toDate(),
    );
  }

  /// Sin el dispositivo a propósito: lo escribe `vincularDispositivo` con la
  /// hora del servidor, y las reglas solo admiten ese cambio por separado.
  Map<String, dynamic> toMap() => {
        'email': email,
        'nombre': nombre,
        'cedula': cedula,
        'programa': programa,
        'tipo_usuario': tipoUsuario,
        'foto_url': fotoUrl,
        'roles': roles,
      };

  bool get esDocente => roles.contains(Rol.docente);
  bool get esEstudiante => roles.contains(Rol.estudiante);

  /// Si ya hay un celular atado a esta cuenta.
  bool get tieneDispositivo => (dispositivoId ?? '').isNotEmpty;

  /// Si se puede vincular otro celular. La primera vez siempre se puede; a
  /// partir de ahí, solo cuando pasó la espera. Es la misma cuenta que hacen
  /// las reglas, repetida aquí para avisar antes de intentarlo en vano.
  bool puedeVincular(DateTime ahora) {
    if (!tieneDispositivo || dispositivoDesde == null) return true;
    return !ahora.isBefore(dispositivoDesde!.add(esperaEntreDispositivos));
  }

  /// Cuándo se podrá cambiar de celular, o null si ya se puede.
  DateTime? proximoCambio(DateTime ahora) => puedeVincular(ahora)
      ? null
      : dispositivoDesde!.add(esperaEntreDispositivos);

  /// El mismo perfil con otro celular atado, para refrescarlo en memoria sin
  /// volver a leer Firestore.
  UsuarioPerfil conDispositivo(String id, DateTime desde) => UsuarioPerfil(
        uid: uid,
        email: email,
        nombre: nombre,
        cedula: cedula,
        programa: programa,
        tipoUsuario: tipoUsuario,
        fotoUrl: fotoUrl,
        roles: roles,
        dispositivoId: id,
        dispositivoDesde: desde,
      );

  /// Docente que también cursa materias: es el único caso en que se pregunta
  /// con qué perfil entrar.
  bool get esDual => esDocente && esEstudiante;

  /// Datos del usuario en el formato que usan las tarjetas de identidad.
  VerificacionResult comoVerificacion({Uint8List? imagenBytes}) {
    return VerificacionResult(
      success: true,
      documentoConsultado: cedula ?? '',
      nombre: nombre,
      cedula: cedula,
      programa: programa,
      tipoUsuario: tipoUsuario,
      fotoUrl: fotoUrl,
      imagenBytes: imagenBytes,
    );
  }
}
