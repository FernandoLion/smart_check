import 'package:flutter/material.dart';

/// El reloj para elegir una hora de clase, igual en toda la app: de 24
/// horas, como se muestran los horarios ("13:30"), y en español. Sin esto,
/// el del celular puede salir en AM/PM en un lado y en 24 horas en otro.
Future<TimeOfDay?> elegirHora(
  BuildContext context, {
  required TimeOfDay inicial,
  required bool esInicio,
}) {
  return showTimePicker(
    context: context,
    initialTime: inicial,
    helpText: esInicio ? 'Hora de inicio' : 'Hora de fin',
    cancelText: 'Cancelar',
    confirmText: 'Listo',
    builder: (context, hijo) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: hijo!,
    ),
  );
}
