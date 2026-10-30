import 'package:flutter/services.dart';

/// El identificador del celular en el que corre la app.
///
/// Como [BleService], es la capa que toca la plataforma: lo que decide qué
/// hacer con el identificador vive en los viewmodels, que así se pueden
/// probar sin teléfono.
///
/// En Android es el `ANDROID_ID`, que va por dispositivo, usuario y clave de
/// firma de la app. Dos límites que hay que tener presentes: **cambia entre
/// el build de debug y el de release**, así que un celular vinculado desde un
/// APK de pruebas aparece como otro distinto al instalar el definitivo; y se
/// reinicia al restaurar el teléfono de fábrica. Fuera de Android (la web)
/// no hay canal y devuelve null: ahí no se puede marcar asistencia, que
/// tampoco se podía, porque el BLE no existe en el navegador.
class DispositivoService {
  static const _canal = MethodChannel('smartcheck/dispositivo');

  /// Se pregunta una vez y se recuerda: el identificador no cambia mientras
  /// la app esté abierta, y esto se llama en cada marcaje.
  String? _recordado;

  Future<String?> identificador() async {
    if (_recordado != null) return _recordado;
    try {
      final id = await _canal.invokeMethod<String>('identificador');
      if (id == null || id.isEmpty) return null;
      return _recordado = id;
    } on MissingPluginException {
      // No hay lado nativo (web, o los tests de widget).
      return null;
    } on PlatformException {
      return null;
    }
  }
}
