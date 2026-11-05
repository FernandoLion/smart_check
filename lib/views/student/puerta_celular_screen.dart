import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/identidad_facial_service.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../attendance/face_verification_screen.dart';

/// Qué hacer cuando un estudiante entra a su portal desde un celular.
enum PasoAlEntrar {
  /// Es el celular vinculado, o no hay nada que comprobar: pasa.
  entrar,

  /// La cuenta todavía no tiene celular: confirma su rostro y queda este.
  vincular,

  /// La cuenta está atada a otro celular: confirma su rostro para pasarse.
  cambiar,
}

/// Decide [PasoAlEntrar] sin tocar la cámara ni el almacén, para poder
/// probarlo.
///
/// - Sin identificador del celular (la web) no hay nada que atar.
/// - Sin rostro de referencia en este celular ni foto en Chairá no hay con
///   qué comparar: se le deja entrar a ver su asistencia, que sin rostro no
///   puede marcar de todos modos.
PasoAlEntrar pasoAlEntrar({
  required String? vinculado,
  required String? esteCelular,
  required bool hayConQueComparar,
}) {
  if (esteCelular == null) return PasoAlEntrar.entrar;
  if (vinculado == esteCelular) return PasoAlEntrar.entrar;
  if (!hayConQueComparar) return PasoAlEntrar.entrar;
  return (vinculado ?? '').isEmpty ? PasoAlEntrar.vincular : PasoAlEntrar.cambiar;
}

/// Antes de entrar al portal del estudiante: si este no es el celular de la
/// cuenta, que demuestre que es él. Devuelve si puede entrar; si no, quien
/// llama cierra la sesión.
///
/// Sin esto, cualquiera con la contraseña de un compañero entraba a su
/// cuenta desde otro teléfono como si nada. Marcar asistencia ya estaba
/// atado al celular vinculado; ahora también entrar.
Future<bool> pasarPuertaDelCelular(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  final perfil = auth.perfil;
  if (perfil == null) return false;

  final esteCelular = await auth.identificadorDeEsteDispositivo();
  // El caso de todos los días, sin tocar el almacén cifrado.
  if (esteCelular == null || esteCelular == perfil.dispositivoId) return true;
  final hayFoto = (perfil.fotoUrl ?? '').isNotEmpty;
  var hayConQueComparar = hayFoto;
  try {
    hayConQueComparar =
        hayFoto || await IdentidadEnCelular.tieneReferencia(perfil.uid);
  } catch (_) {
    // Si el almacén cifrado no responde, decide la foto de Chairá.
  }

  final paso = pasoAlEntrar(
    vinculado: perfil.dispositivoId,
    esteCelular: esteCelular,
    hayConQueComparar: hayConQueComparar,
  );
  if (paso == PasoAlEntrar.entrar) return true;
  if (!context.mounted) return false;
  final entra = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PuertaDelCelularScreen(cambiar: paso == PasoAlEntrar.cambiar),
    ),
  );
  return entra ?? false;
}

/// La pantalla que pide el rostro antes de dejar usar la cuenta en este
/// celular. Al confirmarlo, este queda vinculado y el anterior deja de poder
/// marcar.
class PuertaDelCelularScreen extends StatefulWidget {
  /// La cuenta ya tenía otro celular (y no es que no tuviera ninguno).
  final bool cambiar;

  const PuertaDelCelularScreen({super.key, required this.cambiar});

  @override
  State<PuertaDelCelularScreen> createState() => _PuertaDelCelularScreenState();
}

class _PuertaDelCelularScreenState extends State<PuertaDelCelularScreen> {
  static const _indigo = Color(0xFF5E5CE6);
  static const _ambar = Color(0xFFFF9F0A);

  bool _trabajando = false;

  Future<void> _confirmar() async {
    final auth = context.read<AuthViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final rostro = await verificarRostro(context);
    if (!mounted) return;
    if (rostro == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se confirmó tu rostro: sin eso no puedes usar tu cuenta en '
            'este celular.',
          ),
        ),
      );
      return;
    }
    setState(() => _trabajando = true);
    final listo = await auth.vincularEsteDispositivo();
    if (!mounted) return;
    setState(() => _trabajando = false);
    if (listo) {
      Navigator.pop(context, true);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          auth.errorMessage ?? 'No se pudo vincular este celular.',
        ),
      ),
    );
  }

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Los últimos caracteres del identificador, para distinguirlo sin llenar
  /// la pantalla.
  static String _corto(String id) => id.substring(max(0, id.length - 6));

  @override
  Widget build(BuildContext context) {
    final perfil = context.watch<AuthViewModel>().perfil;
    final otro = perfil?.dispositivoId ?? '';
    final desde = perfil?.dispositivoDesde;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: (widget.cambiar ? _ambar : _indigo)
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.cambiar
                            ? Icons.phonelink_lock
                            : Icons.phone_android,
                        color: widget.cambiar ? _ambar : const Color(0xFFC2C1FF),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.cambiar
                        ? 'Tu cuenta está en otro celular'
                        : 'Vincula este celular',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.cambiar
                        ? 'Tu asistencia se firma desde un solo celular, y tu '
                            'cuenta está vinculada a otro. Para usarla en este, '
                            'confirma que eres tú: si tu rostro coincide, este '
                            'celular queda vinculado y el otro deja de poder '
                            'marcar tu asistencia.'
                        : 'Tu asistencia se firma desde un solo celular. '
                            'Confirma que eres tú y este quedará vinculado a tu '
                            'cuenta.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (widget.cambiar && otro.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.smartphone,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Celular vinculado: terminado en ${_corto(otro)}'
                              '${desde == null ? '' : ', desde el ${_fecha(desde)}'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _trabajando ? null : _confirmar,
                    icon: _trabajando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.face_outlined),
                    label: Text(
                      widget.cambiar
                          ? 'Confirmar mi rostro y usar este'
                          : 'Confirmar mi rostro',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _trabajando ? null : () => Navigator.pop(context, false),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Color(0xFFFF453A), fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Si no puedes confirmar tu rostro, entra desde tu celular '
                    'vinculado o pídele al docente que te marque a mano.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
