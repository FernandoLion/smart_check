package com.example.smart_check

import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity y no FlutterActivity porque el dialogo de huella de
// Android (BiometricPrompt, que usa local_auth) necesita una FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    // El identificador del celular con el que el estudiante marca asistencia.
    // Se lee aqui, y no con un paquete, porque es una sola linea de Android y
    // asi no entra otra dependencia al proyecto.
    private val canalDispositivo = "smartcheck/dispositivo"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canalDispositivo)
            .setMethodCallHandler { llamada, respuesta ->
                if (llamada.method == "identificador") {
                    // ANDROID_ID: unico por dispositivo, usuario y clave de
                    // firma de la app. Cambia entre debug y release, y se
                    // reinicia al restaurar el telefono de fabrica.
                    respuesta.success(
                        Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                    )
                } else {
                    respuesta.notImplemented()
                }
            }
    }
}
