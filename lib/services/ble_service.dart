import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Error de Bluetooth con un mensaje listo para mostrar.
class BleException implements Exception {
  final String mensaje;
  const BleException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Una baliza de SmartCheck que vio el celular del docente.
class BalizaDetectada {
  /// Huella de la clave del estudiante, para comparar con la de los inscritos.
  final int huella;

  /// Fuerza de la señal: más cerca de 0 es más cerca del docente.
  final int rssi;

  const BalizaDetectada({required this.huella, required this.rssi});
}

/// Asistencia por BLE: el celular del estudiante se anuncia y el del docente
/// escanea. Nadie se conecta a nadie; basta con oír el anuncio.
class BleService {
  /// UUID propio de SmartCheck, para que el docente solo oiga balizas de la
  /// app y no cualquier dispositivo del edificio.
  static const uuidServicio = '0000a1ce-0000-1000-8000-00805f9b34fb';

  /// 0xFFFF es el identificador que el Bluetooth SIG deja para pruebas.
  static const _fabricante = 0xFFFF;

  final _periferico = FlutterBlePeripheral();
  StreamSubscription<List<ScanResult>>? _suscripcion;
  StreamController<BalizaDetectada>? _balizas;

  /// Huella de 4 bytes de la clave del estudiante (FNV-1a).
  ///
  /// El anuncio BLE solo admite unos pocos bytes, y además así no viaja la
  /// cédula por el aire: el docente calcula la huella de cada inscrito suyo y
  /// compara.
  static int huellaDe(String clave) {
    var h = 0x811C9DC5;
    for (final byte in utf8.encode(clave.trim().toLowerCase())) {
      h = ((h ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static Uint8List _aBytes(int huella) => Uint8List.fromList([
        (huella >> 24) & 0xFF,
        (huella >> 16) & 0xFF,
        (huella >> 8) & 0xFF,
        huella & 0xFF,
      ]);

  static int _deBytes(List<int> bytes) =>
      (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

  // --- Lado del docente: escuchar -------------------------------------------

  /// Empieza a escanear y devuelve las balizas que va oyendo. El mismo
  /// estudiante aparece muchas veces mientras siga en el aula.
  Stream<BalizaDetectada> escanear() {
    final salida = StreamController<BalizaDetectada>.broadcast(
      onCancel: detenerEscaneo,
    );
    _balizas = salida;
    _arrancarEscaneo(salida);
    return salida.stream;
  }

  Future<void> _arrancarEscaneo(
    StreamController<BalizaDetectada> salida,
  ) async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        throw const BleException('Este dispositivo no tiene Bluetooth LE.');
      }
      // Recién inicializado el adaptador el estado en caché es `unknown`, así
      // que se espera al primero de verdad antes de dar por apagado el radio.
      final estado = await FlutterBluePlus.adapterState
          .firstWhere((e) => e != BluetoothAdapterState.unknown)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => FlutterBluePlus.adapterStateNow,
          );
      if (estado != BluetoothAdapterState.on) {
        throw const BleException('Enciende el Bluetooth para pasar lista.');
      }
      _suscripcion = FlutterBluePlus.scanResults.listen((resultados) {
        for (final resultado in resultados) {
          final datos = resultado.advertisementData.manufacturerData[_fabricante];
          if (datos == null || datos.length < 4) continue;
          salida.add(
            BalizaDetectada(huella: _deBytes(datos), rssi: resultado.rssi),
          );
        }
      });
      await FlutterBluePlus.startScan(
        withServices: [Guid(uuidServicio)],
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      salida.addError(e is BleException ? e : BleException(_mensaje(e)));
    }
  }

  Future<void> detenerEscaneo() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Si el escaneo ya estaba detenido no hay nada que avisar.
    }
    await _balizas?.close();
    _balizas = null;
  }

  // --- Lado del estudiante: anunciarse --------------------------------------

  /// Pone el celular a anunciar la huella de [clave] hasta que se le diga que
  /// pare.
  Future<void> anunciar(String clave) async {
    if (!await _periferico.isSupported) {
      throw const BleException(
        'Este celular no puede anunciarse por Bluetooth. Pídele al docente '
        'que te marque a mano.',
      );
    }
    var estado = await _periferico.hasPermission();
    if (estado != PeripheralBluetoothState.granted &&
        estado != PeripheralBluetoothState.ready) {
      estado = await _periferico.requestPermission();
    }
    _comprobar(estado);
    try {
      _comprobar(
        await _periferico.start(
          advertiseData: AdvertiseDataCore(
            serviceUuid: uuidServicio,
            manufacturerId: _fabricante,
            manufacturerData: _aBytes(huellaDe(clave)),
          ),
        ),
      );
    } on BleException {
      rethrow;
    } catch (e) {
      throw BleException(_mensaje(e));
    }
  }

  Future<void> dejarDeAnunciar() async {
    try {
      await _periferico.stop();
    } catch (_) {
      // Si ya no se estaba anunciando, no hay nada que avisar.
    }
  }

  void _comprobar(PeripheralBluetoothState estado) {
    switch (estado) {
      case PeripheralBluetoothState.granted:
      case PeripheralBluetoothState.ready:
        return;
      case PeripheralBluetoothState.turnedOff:
        throw const BleException('Enciende el Bluetooth para marcar.');
      case PeripheralBluetoothState.unsupported:
        throw const BleException(
          'Este celular no puede anunciarse por Bluetooth.',
        );
      case PeripheralBluetoothState.permanentlyDenied:
        throw const BleException(
          'Dale permiso de Bluetooth a SmartCheck desde los ajustes del '
          'celular.',
        );
      case PeripheralBluetoothState.denied:
      case PeripheralBluetoothState.restricted:
      case PeripheralBluetoothState.limited:
      case PeripheralBluetoothState.unknown:
        throw const BleException(
          'Sin permiso de Bluetooth no se puede marcar la asistencia.',
        );
    }
  }

  static String _mensaje(Object e) {
    final texto = e.toString();
    if (texto.contains('permission') || texto.contains('Permission')) {
      return 'Falta el permiso de Bluetooth.';
    }
    return 'Error de Bluetooth: $texto';
  }
}
