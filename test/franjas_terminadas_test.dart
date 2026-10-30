import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/curso_service.dart';

/// Un llamado de diez minutos del día 20, dentro del bloque de [bloqueHora].
Sesion llamado(
  String id,
  int hora,
  int minuto, {
  bool abierta = false,
  int? bloqueHora,
}) =>
    Sesion(
      id: id,
      inicio: DateTime(2026, 10, 20, hora, minuto),
      fin: DateTime(2026, 10, 20, hora, minuto + 10),
      abierta: abierta,
      bloqueInicio:
          bloqueHora == null ? null : DateTime(2026, 10, 20, bloqueHora),
    );

void main() {
  // Mitad de la clase de las 10, así que la de las 8 ya es pasado.
  final ahora = DateTime(2026, 10, 20, 10, 30);

  group('franjas terminadas', () {
    test('dos llamados del mismo bloque son una sola clase', () {
      final franjas = CursoService.franjasTerminadas([
        llamado('s1', 8, 2, bloqueHora: 8),
        llamado('s2', 8, 40, bloqueHora: 8),
      ], ahora);

      expect(franjas, hasLength(1));
      expect(franjas.values.single.map((s) => s.id), ['s1', 's2']);
    });

    test('bloques distintos son clases distintas', () {
      final franjas = CursoService.franjasTerminadas([
        llamado('s1', 8, 2, bloqueHora: 8),
        llamado('s2', 9, 5, bloqueHora: 9),
      ], ahora);

      expect(franjas, hasLength(2));
    });

    test('el llamado que sigue vigente todavía no cuenta', () {
      final franjas = CursoService.franjasTerminadas([
        llamado('s1', 10, 25, abierta: true, bloqueHora: 10),
      ], ahora);

      expect(franjas, isEmpty);
    });

    test('el llamado que quedó abierto y venció sí cuenta', () {
      final franjas = CursoService.franjasTerminadas([
        llamado('s1', 8, 2, abierta: true, bloqueHora: 8),
      ], ahora);

      expect(franjas, hasLength(1));
    });

    test('las sesiones viejas sin franja se agrupan por su inicio', () {
      // Antes de la ventana de diez minutos, la sesión era la franja entera.
      final franjas = CursoService.franjasTerminadas([
        llamado('s1', 8, 0),
        llamado('s2', 8, 0),
      ], ahora);

      expect(franjas, hasLength(1));
    });
  });
}
