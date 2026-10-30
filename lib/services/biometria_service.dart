import 'package:local_auth/local_auth.dart';

/// Cómo acabó la comprobación del dueño del celular.
enum ResultadoBiometria {
  /// El teléfono reconoció a quien registró su huella (o su cara).
  biometrica,

  /// El teléfono no tiene biometría, pero sí bloqueo de pantalla, y el PIN
  /// o el patrón fueron correctos.
  credencial,

  /// El celular no tiene ni huella ni bloqueo de pantalla: no hay nada que
  /// comprobar. No corta el marcaje, pero queda escrito en la presencia
  /// para que el docente lo vea.
  noDisponible,

  /// Se pidió y no pasó: se canceló, falló, o el sensor está bloqueado por
  /// demasiados intentos. Esto sí corta el marcaje.
  rechazada,
}

/// Le pregunta al propio teléfono si quien lo está usando es su dueño.
///
/// Es la pieza más fuerte y más barata de la cadena: la comparación la hace
/// el hardware seguro del celular contra la huella que su dueño registró, sin
/// modelo, sin umbrales y sin que la app vea nunca el dato biométrico.
///
/// Lo que prueba, dicho con precisión: que **alguien registrado en ese
/// teléfono** autorizó el marcaje. No prueba que sea el estudiante — si él
/// registró la huella de un amigo en su propio celular, el amigo pasa. Por
/// eso esto va encima de la vinculación del dispositivo y no en su lugar.
///
/// Y como todo lo que corre en el celular, el servidor no puede comprobarlo:
/// un APK modificado se lo salta. Lo que sí queda atado al servidor es desde
/// qué celular se firmó.
class BiometriaService {
  BiometriaService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<ResultadoBiometria> comprobar() async {
    try {
      // `isDeviceSupported` mira el bloqueo de pantalla; `canCheckBiometrics`,
      // el sensor. Si no hay ninguno de los dos no se le puede pedir nada al
      // teléfono, y dejar fuera a quien tenga el celular más barato del salón
      // sería peor que no tener esto.
      if (!await _auth.isDeviceSupported()) return ResultadoBiometria.noDisponible;
      final conHuella = await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;

      final listo = await _auth.authenticate(
        localizedReason: 'Confirma que eres tú para marcar tu asistencia.',
        // A propósito en false: con true, quien no tenga huella registrada no
        // podría marcar nunca.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!listo) return ResultadoBiometria.rechazada;
      // Lo que se apunta es qué tenía el teléfono para comprobar, no con cuál
      // de las dos lo hizo: el sistema no lo dice, y con huella registrada el
      // usuario todavía puede elegir el PIN en el propio diálogo.
      return conHuella
          ? ResultadoBiometria.biometrica
          : ResultadoBiometria.credencial;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware =>
          ResultadoBiometria.noDisponible,
        _ => ResultadoBiometria.rechazada,
      };
    } catch (_) {
      return ResultadoBiometria.rechazada;
    }
  }
}

/// Lo que se escribe en la presencia firmada.
extension TextoDeBiometria on ResultadoBiometria {
  String get comoDato => switch (this) {
        ResultadoBiometria.biometrica => 'biometrica',
        ResultadoBiometria.credencial => 'credencial',
        ResultadoBiometria.noDisponible => 'no_disponible',
        ResultadoBiometria.rechazada => 'rechazada',
      };

  /// Si deja seguir con el marcaje.
  bool get deja => this != ResultadoBiometria.rechazada;
}
