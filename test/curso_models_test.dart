import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';

void main() {
  group('Horario', () {
    const martes8a10 = Horario(dia: DateTime.tuesday, inicio: '08:00', fin: '10:00');

    test('contiene solo el día y la franja indicados', () {
      // 2026-10-20 es martes.
      expect(martes8a10.contiene(DateTime(2026, 10, 20, 8, 0)), isTrue);
      expect(martes8a10.contiene(DateTime(2026, 10, 20, 9, 59)), isTrue);
      expect(martes8a10.contiene(DateTime(2026, 10, 20, 10, 0)), isFalse);
      expect(martes8a10.contiene(DateTime(2026, 10, 20, 7, 59)), isFalse);
      expect(martes8a10.contiene(DateTime(2026, 10, 21, 9, 0)), isFalse);
    });
  });

  group('Geocerca', () {
    // Centro aproximado de un campus en Florencia, Caquetá.
    const aula = Geocerca(latitud: 1.6200, longitud: -75.6050, radioMetros: 50);

    test('acepta puntos dentro del radio y rechaza los de fuera', () {
      expect(aula.contiene(1.6200, -75.6050), isTrue);
      // ~33 m al norte.
      expect(aula.contiene(1.6203, -75.6050), isTrue);
      // ~111 m al norte.
      expect(aula.contiene(1.6210, -75.6050), isFalse);
    });

    test('calcula distancias razonables', () {
      expect(aula.distanciaA(1.6210, -75.6050), closeTo(111, 2));
    });
  });

  group('Curso', () {
    const curso = Curso(
      codigo: 'SIS-402',
      nombre: 'Ingeniería de Software II',
      grupo: '302-B',
      aula: 'Aula 204',
      periodo: '2026-2',
      docenteUid: 'uid-docente',
      docenteNombre: 'ANA MARÍA PÉREZ GÓMEZ',
      horarios: [
        Horario(dia: DateTime.tuesday, inicio: '08:00', fin: '10:00'),
        Horario(dia: DateTime.thursday, inicio: '08:00', fin: '10:00'),
      ],
      geocerca: Geocerca(latitud: 1.62, longitud: -75.605, radioMetros: 40),
      clavesInscritos: ['1117000000', 'an.perez@udla.edu.co'],
    );

    test('se guarda y se lee igual', () {
      final leido = Curso.fromMap('c1', curso.toMap());

      expect(leido.id, 'c1');
      expect(leido.toMap(), curso.toMap());
      expect(leido.horarios, hasLength(2));
      expect(leido.geocerca!.radioMetros, 40);
    });

    test('lee cursos sin geocerca ni horarios', () {
      final leido = Curso.fromMap('c2', {'codigo': 'X', 'nombre': 'Y'});

      expect(leido.geocerca, isNull);
      expect(leido.horarios, isEmpty);
      expect(leido.clavesInscritos, isEmpty);
    });

    test('calcula el periodo académico por semestre', () {
      expect(Curso.periodoActual(DateTime(2026, 6, 30)), '2026-1');
      expect(Curso.periodoActual(DateTime(2026, 7, 1)), '2026-2');
    });

    test('encuentra el bloque de horario en curso', () {
      expect(curso.horarioEn(DateTime(2026, 10, 22, 9, 30))?.dia,
          DateTime.thursday);
      expect(curso.horarioEn(DateTime(2026, 10, 23, 9, 30)), isNull);
    });
  });

  group('Inscrito', () {
    test('usa la cédula como clave si la tiene', () {
      const inscrito = Inscrito(
        cedula: '1117000000',
        email: 'An.Perez@udla.edu.co',
        nombre: 'ANA MARÍA PÉREZ GÓMEZ',
      );
      expect(inscrito.clave, '1117000000');
      expect(inscrito.claves, ['1117000000', 'an.perez@udla.edu.co']);
    });

    test('usa el correo en minúsculas si no hay cédula', () {
      const inscrito =
          Inscrito(email: 'CA.Munoz@udla.edu.co', nombre: 'CARLOS MUÑOZ');
      expect(inscrito.clave, 'ca.munoz@udla.edu.co');
      expect(inscrito.claves, ['ca.munoz@udla.edu.co']);
    });

    test('se guarda y se lee igual', () {
      const inscrito = Inscrito(cedula: '1117000000', nombre: 'ANA');
      expect(Inscrito.fromMap(inscrito.toMap()).toMap(), inscrito.toMap());
    });
  });

  group('Sesion', () {
    final sesion = Sesion(
      inicio: DateTime(2026, 10, 20, 8),
      fin: DateTime(2026, 10, 20, 10),
    );

    test('admite asistencia solo abierta y dentro de la franja', () {
      expect(sesion.admiteAsistencia(DateTime(2026, 10, 20, 8)), isTrue);
      expect(sesion.admiteAsistencia(DateTime(2026, 10, 20, 9, 59)), isTrue);
      expect(sesion.admiteAsistencia(DateTime(2026, 10, 20, 10)), isFalse);
      expect(sesion.admiteAsistencia(DateTime(2026, 10, 20, 7, 59)), isFalse);

      final cerrada = Sesion(
        inicio: sesion.inicio,
        fin: sesion.fin,
        abierta: false,
      );
      expect(cerrada.admiteAsistencia(DateTime(2026, 10, 20, 9)), isFalse);
    });

    test('se guarda y se lee igual', () {
      final leida = Sesion.fromMap('s1', sesion.toMap());
      expect(leida.id, 's1');
      expect(leida.inicio, sesion.inicio);
      expect(leida.fin, sesion.fin);
      expect(leida.abierta, isTrue);
    });

    test('el llamado dura diez minutos desde que lo abre el docente', () {
      final llamado = Sesion.llamado(
        ahora: DateTime(2026, 10, 20, 8, 30),
        bloqueInicio: DateTime(2026, 10, 20, 8),
        bloqueFin: DateTime(2026, 10, 20, 10),
      );

      expect(llamado.inicio, DateTime(2026, 10, 20, 8, 30));
      expect(llamado.fin, DateTime(2026, 10, 20, 8, 40));
      expect(llamado.franja, DateTime(2026, 10, 20, 8));
      expect(llamado.abierta, isTrue);
    });

    test('el llamado no pasa del final del bloque', () {
      final llamado = Sesion.llamado(
        ahora: DateTime(2026, 10, 20, 9, 56),
        bloqueInicio: DateTime(2026, 10, 20, 8),
        bloqueFin: DateTime(2026, 10, 20, 10),
      );

      expect(llamado.fin, DateTime(2026, 10, 20, 10));
    });

    test('guarda y lee la franja del bloque', () {
      final llamado = Sesion.llamado(
        ahora: DateTime(2026, 10, 20, 8, 30),
        bloqueInicio: DateTime(2026, 10, 20, 8),
        bloqueFin: DateTime(2026, 10, 20, 10),
      );

      expect(Sesion.fromMap('s1', llamado.toMap()).franja, llamado.franja);
    });

    test('una sesión sin bloque_inicio usa su inicio como franja', () {
      // Las que se escribieron antes de que el llamado durara diez minutos.
      final vieja = Sesion.fromMap('s1', {
        'inicio': Timestamp.fromDate(DateTime(2026, 10, 20, 8)),
        'fin': Timestamp.fromDate(DateTime(2026, 10, 20, 10)),
        'abierta': false,
      });

      expect(vieja.bloqueInicio, isNull);
      expect(vieja.franja, DateTime(2026, 10, 20, 8));
    });

    test('lo que queda de llamado nunca es negativo', () {
      expect(
        sesion.restante(DateTime(2026, 10, 20, 9)),
        const Duration(hours: 1),
      );
      expect(sesion.restante(DateTime(2026, 10, 20, 11)), Duration.zero);
      expect(sesion.vencida(DateTime(2026, 10, 20, 9, 59)), isFalse);
      expect(sesion.vencida(DateTime(2026, 10, 20, 10)), isTrue);
    });
  });

  group('Asistencia', () {
    test('se guarda y se lee igual', () {
      final asistencia = Asistencia(
        claveInscrito: '1117000000',
        estado: EstadoAsistencia.tarde,
        metodo: MetodoAsistencia.ble,
        hora: DateTime(2026, 10, 20, 8, 20),
        registradoPor: 'uid-docente',
      );
      final leida = Asistencia.fromMap('1117000000', asistencia.toMap());

      expect(leida.toMap(), asistencia.toMap());
      expect(leida.claveInscrito, '1117000000');
      expect(leida.cuentaComoAsistio, isTrue);
    });

    test('ausente no cuenta como asistencia', () {
      final ausente = Asistencia(
        claveInscrito: 'x',
        estado: EstadoAsistencia.ausente,
        metodo: MetodoAsistencia.manual,
        hora: DateTime(2026),
        registradoPor: 'uid',
      );
      expect(ausente.cuentaComoAsistio, isFalse);
    });
  });
}
