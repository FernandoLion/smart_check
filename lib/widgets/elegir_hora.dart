import 'package:flutter/material.dart';

/// El reloj para elegir una hora de clase, igual en toda la app: con AM y
/// PM, aunque el celular esté en 24 horas, y con los textos en español.
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
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: hijo!,
    ),
  );
}

/// "1:30 PM": la hora como la muestra ese reloj.
String horaAmPm(TimeOfDay t) {
  final hora = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minutos = t.minute.toString().padLeft(2, '0');
  return '$hora:$minutos ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// [horaAmPm] de los minutos desde la medianoche (así guarda las horas el
/// horario del curso).
String horaAmPmDeMinutos(int minutos) =>
    horaAmPm(TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60));
