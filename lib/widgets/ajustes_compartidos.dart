import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/asistencia_resumen.dart';
import '../models/sesion_model.dart';
import '../utils/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Piezas que comparten los Ajustes del docente y del estudiante: el estado
/// real de los permisos del celular, la ayuda, qué datos se usan y el cambio
/// de contraseña.

// --- Permisos --------------------------------------------------------------

/// Cómo está un requisito del celular para marcar o pasar lista.
enum EstadoPermiso { listo, falta, apagado, noDisponible, revisando }

/// Los permisos y radios que la asistencia necesita, leídos del celular cada
/// vez que se muestra la pantalla o se vuelve a ella desde los ajustes del
/// sistema. Tocar uno que falte lo pide, o abre los ajustes del sistema.
class PermisosDelCelular extends StatefulWidget {
  const PermisosDelCelular({super.key});

  @override
  State<PermisosDelCelular> createState() => _PermisosDelCelularState();
}

class _PermisosDelCelularState extends State<PermisosDelCelular>
    with WidgetsBindingObserver {
  var _bluetooth = EstadoPermiso.revisando;
  var _cercanos = EstadoPermiso.revisando;
  var _ubicacion = EstadoPermiso.revisando;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _revisar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema el permiso pudo cambiar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _revisar();
  }

  Future<void> _revisar() async {
    final resultados = await Future.wait([
      _estadoBluetooth(),
      _estadoCercanos(),
      _estadoUbicacion(),
    ]);
    if (!mounted) return;
    setState(() {
      _bluetooth = resultados[0];
      _cercanos = resultados[1];
      _ubicacion = resultados[2];
    });
  }

  static Future<EstadoPermiso> _estadoBluetooth() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        return EstadoPermiso.noDisponible;
      }
      final estado = await FlutterBluePlus.adapterState
          .firstWhere((e) => e != BluetoothAdapterState.unknown)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => FlutterBluePlus.adapterStateNow,
          );
      return estado == BluetoothAdapterState.on
          ? EstadoPermiso.listo
          : EstadoPermiso.apagado;
    } catch (_) {
      return EstadoPermiso.noDisponible;
    }
  }

  static Future<EstadoPermiso> _estadoCercanos() async {
    try {
      final estado = await FlutterBlePeripheral().hasPermission();
      switch (estado) {
        case PeripheralBluetoothState.granted:
        case PeripheralBluetoothState.ready:
        case PeripheralBluetoothState.turnedOff:
          return EstadoPermiso.listo;
        case PeripheralBluetoothState.unsupported:
          return EstadoPermiso.noDisponible;
        case PeripheralBluetoothState.denied:
        case PeripheralBluetoothState.permanentlyDenied:
        case PeripheralBluetoothState.restricted:
        case PeripheralBluetoothState.limited:
        case PeripheralBluetoothState.unknown:
          return EstadoPermiso.falta;
      }
    } catch (_) {
      return EstadoPermiso.noDisponible;
    }
  }

  static Future<EstadoPermiso> _estadoUbicacion() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.unableToDetermine) {
        return EstadoPermiso.falta;
      }
      return await Geolocator.isLocationServiceEnabled()
          ? EstadoPermiso.listo
          : EstadoPermiso.apagado;
    } catch (_) {
      return EstadoPermiso.noDisponible;
    }
  }

  Future<void> _arreglarBluetooth() async {
    try {
      // En Android abre el diálogo del sistema para encenderlo.
      await FlutterBluePlus.turnOn();
    } catch (_) {
      await Geolocator.openAppSettings();
    }
    await _revisar();
  }

  Future<void> _arreglarCercanos() async {
    final periferico = FlutterBlePeripheral();
    final estado = await periferico.requestPermission();
    if (estado == PeripheralBluetoothState.permanentlyDenied ||
        estado == PeripheralBluetoothState.denied) {
      await Geolocator.openAppSettings();
    }
    await _revisar();
  }

  Future<void> _arreglarUbicacion() async {
    if (_ubicacion == EstadoPermiso.apagado) {
      await Geolocator.openLocationSettings();
    } else {
      final permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.denied) {
        await Geolocator.openAppSettings();
      }
    }
    await _revisar();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _fila(
            icono: Icons.bluetooth,
            titulo: 'Bluetooth',
            detalle: 'Por aquí se oyen los celulares de la clase',
            estado: _bluetooth,
            arreglar: _arreglarBluetooth,
          ),
          const _Separador(),
          _fila(
            icono: Icons.sensors,
            titulo: 'Dispositivos cercanos',
            detalle: 'Permiso para anunciarse y escanear por Bluetooth',
            estado: _cercanos,
            arreglar: _arreglarCercanos,
          ),
          const _Separador(),
          _fila(
            icono: Icons.near_me_outlined,
            titulo: 'Ubicación',
            detalle: 'Comprueba que estés dentro del aula',
            estado: _ubicacion,
            arreglar: _arreglarUbicacion,
          ),
        ],
      ),
    );
  }

  Widget _fila({
    required IconData icono,
    required String titulo,
    required String detalle,
    required EstadoPermiso estado,
    required Future<void> Function() arreglar,
  }) {
    final (texto, color) = switch (estado) {
      EstadoPermiso.listo => ('Listo', AppTheme.success),
      EstadoPermiso.falta => ('Falta', const Color(0xFFFF9F0A)),
      EstadoPermiso.apagado => ('Apagado', const Color(0xFFFF9F0A)),
      EstadoPermiso.noDisponible => ('No disponible', AppTheme.textTertiary),
      EstadoPermiso.revisando => ('Revisando...', AppTheme.textTertiary),
    };
    final puedeArreglar =
        estado == EstadoPermiso.falta || estado == EstadoPermiso.apagado;
    final etiqueta = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return InkWell(
      onTap: puedeArreglar ? arreglar : _revisar,
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Con poco ancho (pantalla angosta o letra grande) la etiqueta baja
        // debajo del texto, para no partir palabras.
        child: LayoutBuilder(
          builder: (context, caja) {
            final abajo =
                caja.maxWidth < MediaQuery.textScalerOf(context).scale(300);
            return Row(
              children: [
                if (!abajo) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceControl,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icono,
                      color: const Color(0xFFC2C1FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        puedeArreglar ? 'Toca para arreglarlo' : detalle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (abajo) ...[const SizedBox(height: 6), etiqueta],
                    ],
                  ),
                ),
                if (!abajo) ...[const SizedBox(width: 8), etiqueta],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white.withValues(alpha: 0.08),
      );
}

// --- Cuenta ----------------------------------------------------------------

/// Manda al correo institucional de la cuenta el enlace de Firebase para
/// poner una contraseña nueva. Pregunta antes, porque sale un correo.
Future<void> pedirCambioDeContrasena(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  final correo = auth.perfil?.email;
  final messenger = ScaffoldMessenger.of(context);
  if (correo == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Tu sesión expiró. Vuelve a entrar.')),
    );
    return;
  }
  final confirma = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      title: const Text(
        'Cambiar contraseña',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Te enviaremos a $correo un enlace para poner una contraseña nueva. '
        'La de ahora sigue sirviendo hasta que la cambies.',
        style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogo, true),
          child: const Text('Enviar enlace'),
        ),
      ],
    ),
  );
  if (confirma != true) return;
  final enviado = await auth.recoverPassword(correo);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        enviado
            ? 'Listo: revisa $correo (también la carpeta de spam).'
            : auth.errorMessage ?? 'No se pudo enviar el enlace.',
      ),
      backgroundColor: enviado ? null : AppTheme.error,
    ),
  );
}

// --- Ayuda y privacidad ----------------------------------------------------

/// Cómo se usa la app, paso a paso, según quién la usa.
Future<void> mostrarAyuda(BuildContext context, {required bool docente}) {
  const minutos = Sesion.minutosLlamado;
  const minimo = AsistenciaResumen.minimo;
  final pasos = docente
      ? const [
          (
            'Crea el curso',
            'Con su horario y la geocerca del aula: párate en el aula y toca '
                'la insignia de geocerca para marcar el punto.',
          ),
          (
            'Inscribe a los estudiantes',
            'Por cédula (se verifica en Chairá), por correo institucional o '
                'pegando la lista que exporta Chairá.',
          ),
          (
            'Abre el radar en clase',
            'Solo durante el bloque del horario y dentro de la geocerca. Se '
                'abre un llamado de $minutos minutos.',
          ),
          (
            'Los estudiantes marcan',
            'Cada uno confirma su rostro y su huella o PIN, y su celular se '
                'anuncia por Bluetooth. El radar lo marca solo.',
          ),
          (
            'Cierra y corrige',
            'A quien no apareció lo marcas a mano al cerrar el llamado, o '
                'después desde el detalle de la sesión.',
          ),
        ]
      : const [
          (
            'Vincula tu celular',
            'En Carné → "Vincular este celular". Tu asistencia solo se firma '
                'desde el celular vinculado.',
          ),
          (
            'Registra tu rostro',
            'En Ajustes → "Registrar mi rostro". Se compara con tu foto de '
                'Chairá y se guarda solo en este celular.',
          ),
          (
            'Marca en clase',
            'Cuando el docente abra el radar, toca "Registrar asistencia": '
                'confirmas tu rostro y tu huella o PIN, y tu celular se '
                'anuncia por Bluetooth.',
          ),
          (
            'Espera a aparecer',
            'Deja la app abierta, con el Bluetooth y la ubicación encendidos, '
                'hasta que termine el llamado ($minutos minutos).',
          ),
          (
            'Cuida tu porcentaje',
            'Con menos del $minimo% de asistencia se reprueba la materia. Si '
                'algo falla, el docente puede marcarte a mano.',
          ),
        ];
  final problemas = docente
      ? const [
          '"Fuera del horario": el radar solo abre en el bloque del curso.',
          '"Estás a X m del aula": acércate o vuelve a marcar la geocerca.',
          'Un estudiante no aparece: que tenga el Bluetooth encendido, la app '
              'abierta y el celular vinculado. Si no, márcalo a mano.',
        ]
      : const [
          '"Ninguno de tus docentes tiene el llamado abierto": espera a que '
              'el docente abra el radar.',
          '"Tu asistencia está atada a otro celular": vincula este desde '
              'Carné, o marca con el otro.',
          'No apareces en el radar: revisa los permisos en Ajustes y no '
              'cierres la app.',
        ];
  return _hoja(
    context,
    titulo: docente ? 'Cómo pasar lista' : 'Cómo marcar asistencia',
    hijos: [
      for (final (i, paso) in pasos.indexed)
        _Paso(numero: i + 1, titulo: paso.$1, texto: paso.$2),
      const SizedBox(height: 8),
      const _Subtitulo('Si algo falla'),
      for (final p in problemas) _Vineta(p),
    ],
  );
}

/// Qué datos usa la app y dónde quedan. Describe lo que hace el código, no
/// un texto legal genérico.
Future<void> mostrarPrivacidad(BuildContext context) {
  return _hoja(
    context,
    titulo: 'Tus datos en SmartCheck',
    hijos: const [
      _Subtitulo('De Chairá'),
      _Vineta(
        'Tu nombre, documento, programa y la foto del carné, para comprobar '
        'quién eres al crear la cuenta. La foto no se guarda en la base de '
        'datos: se pide a Chairá cuando hace falta.',
      ),
      _Subtitulo('Tu rostro'),
      _Vineta(
        'Se guarda solo en este celular, cifrado y como una lista de números, '
        'no como foto. No sale del celular y lo puedes borrar en Ajustes.',
      ),
      _Vineta(
        'Al marcar, viaja al docente el resultado de la comparación (si '
        'coincidió y qué tanto), nunca la imagen.',
      ),
      _Subtitulo('Huella o PIN'),
      _Vineta(
        'Los comprueba el propio teléfono. SmartCheck solo sabe si se '
        'confirmó o no.',
      ),
      _Subtitulo('Ubicación y Bluetooth'),
      _Vineta(
        'La ubicación se consulta al abrir el radar o al marcar, para ver si '
        'estás en el aula. No se guarda.',
      ),
      _Vineta(
        'Por Bluetooth tu celular anuncia una huella de 4 bytes calculada a '
        'partir de tu documento, no el documento.',
      ),
      _Subtitulo('En la base de datos'),
      _Vineta(
        'Tu perfil, el identificador del celular vinculado y su historial de '
        'cambios, los cursos y cada asistencia con su hora y cómo se marcó.',
      ),
    ],
  );
}

Future<void> _hoja(
  BuildContext context, {
  required String titulo,
  required List<Widget> hijos,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (hoja) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scroll) => SafeArea(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      ),
    ),
  );
}

class _Paso extends StatelessWidget {
  final int numero;
  final String titulo;
  final String texto;

  const _Paso({required this.numero, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppTheme.primary,
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final String texto;
  const _Subtitulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Vineta extends StatelessWidget {
  final String texto;
  const _Vineta(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 10),
              child: CircleAvatar(radius: 2.5, backgroundColor: Colors.white54),
            ),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
