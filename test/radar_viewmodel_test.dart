import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/services/ble_service.dart';
import 'package:smart_check/services/ubicacion_service.dart';
import 'package:smart_check/services/curso_service.dart';
import 'package:smart_check/viewmodels/radar_viewmodel.dart';

import 'ble_fakes.dart';
import 'curso_fakes.dart';

void main() {
  late FakeCursoService cursos;
  late FakeBleService ble;
  late FakeUbicacionService ubicacion;
  late RadarViewModel vm;

  /// Otro radar sobre los mismos fakes, para los casos en los que el docente
  /// vuelve a entrar a la pantalla.
  RadarViewModel otroRadar({DateTime Function()? reloj}) {
    final otro = RadarViewModel(
      cursos: cursos,
      ble: ble,
      ubicacion: ubicacion,
      reloj: reloj,
    );
    addTearDown(otro.dispose);
    return otro;
  }

  setUp(() {
    cursos = FakeCursoService();
    cursos.inscritosPorCurso['c1'] = {
      '1117000000': const Inscrito(cedula: '1117000000', nombre: 'ANA PÉREZ'),
      'ca.munoz@udla.edu.co': const Inscrito(
        email: 'ca.munoz@udla.edu.co',
        nombre: 'CARLOS MUÑOZ',
      ),
    };
    ble = FakeBleService();
    ubicacion = FakeUbicacionService();
    vm = RadarViewModel(cursos: cursos, ble: ble, ubicacion: ubicacion);
  });

  tearDown(() => vm.dispose());

  group('huella BLE', () {
    test('es la misma para la misma clave, sin importar mayúsculas', () {
      expect(
        BleService.huellaDe('CA.Munoz@udla.edu.co'),
        BleService.huellaDe('ca.munoz@udla.edu.co'),
      );
    });

    test('distingue a dos estudiantes', () {
      expect(
        BleService.huellaDe('1117000000'),
        isNot(BleService.huellaDe('1117000001')),
      );
    });

    test('cabe en los 4 bytes del anuncio', () {
      expect(BleService.huellaDe('1117000000'), lessThan(0x100000000));
      expect(BleService.huellaDe('1117000000'), greaterThanOrEqualTo(0));
    });
  });

  group('condiciones para abrir el radar', () {
    test('fuera del horario no abre la clase', () async {
      final ahora = DateTime.now();
      // Mismo curso, pero con la franja en otro día de la semana.
      final curso = cursoEnClase(dia: ahora.weekday == 1 ? 2 : 1);

      expect(await vm.iniciar(curso, 'uid-docente'), isFalse);
      expect(vm.error, contains('Fuera del horario'));
      expect(ble.escaneando, isFalse);
      expect(cursos.sesionesPorCurso['c1'], anyOf(isNull, isEmpty));
    });

    test('fuera de la geocerca no abre la clase', () async {
      // ~1.1 km al norte del aula.
      ubicacion.posicion = posicionEn(aula.latitud + 0.01, aula.longitud);

      expect(
        await vm.iniciar(cursoEnClase(geocerca: aula), 'uid-docente'),
        isFalse,
      );
      expect(vm.error, contains('del aula'));
      expect(ble.escaneando, isFalse);
    });

    test('dentro de la geocerca y en horario sí abre', () async {
      expect(
        await vm.iniciar(cursoEnClase(geocerca: aula), 'uid-docente'),
        isTrue,
      );
      expect(vm.escaneando, isTrue);
      expect(vm.sesion, isNotNull);
      expect(vm.totalInscritos, 2);
      expect(vm.detectados, 0);
    });

    test('un curso sin geocerca no exige ubicación', () async {
      ubicacion.fallo = const UbicacionException('sin permiso');

      expect(await vm.iniciar(cursoEnClase(), 'uid-docente'), isTrue);
      expect(vm.escaneando, isTrue);
    });

    test('a una clase que se está acabando no le abre llamado', () async {
      final curso = cursoEnClase(termina: const Duration(minutes: 1));

      expect(await vm.iniciar(curso, 'uid-docente'), isFalse);
      expect(vm.error, contains('a mano'));
      expect(cursos.sesionesPorCurso['c1'], anyOf(isNull, isEmpty));
    });
  });

  group('ventana del llamado', () {
    test('el llamado dura diez minutos y guarda la franja', () async {
      final ahora = DateTime(2026, 10, 29, 9, 17);
      final radar = otroRadar(reloj: () => ahora);

      expect(await radar.iniciar(cursoEnClase(ahora: ahora), 'uid-docente'),
          isTrue);

      expect(radar.sesion!.inicio, ahora);
      expect(radar.sesion!.fin, ahora.add(Sesion.duracionLlamado));
      // La franja es el bloque de clase, que arrancó cinco minutos antes.
      expect(radar.sesion!.bloqueInicio, DateTime(2026, 10, 29, 9, 12));
      expect(radar.restanteDelLlamado, Sesion.duracionLlamado);
      expect(radar.llamadoVencido, isFalse);
    });

    test('el llamado no pasa del final del bloque', () async {
      final ahora = DateTime(2026, 10, 29, 9, 17);
      final radar = otroRadar(reloj: () => ahora);
      final curso = cursoEnClase(
        ahora: ahora,
        termina: const Duration(minutes: 4),
      );

      await radar.iniciar(curso, 'uid-docente');

      expect(radar.sesion!.fin, DateTime(2026, 10, 29, 9, 21));
    });

    test('cerrar el llamado apaga el escaneo pero deja marcar a mano',
        () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');
      final sesionId = vm.sesion!.id;

      await vm.cerrarLlamado();

      expect(vm.escaneando, isFalse);
      expect(ble.escaneando, isFalse);
      expect(cursos.sesion('c1', sesionId).abierta, isFalse);
      // La sesión sigue en memoria: el llamado manual del docente se hace
      // justo cuando se cierra la ventana.
      expect(vm.sesion, isNotNull);
      final carlos = cursos.inscritosPorCurso['c1']!['ca.munoz@udla.edu.co']!;
      expect(await vm.marcarManual(carlos), isTrue);
    });

    test('volver a entrar al radar con el llamado abierto reusa el mismo',
        () async {
      final curso = cursoEnClase();
      await vm.iniciar(curso, 'uid-docente');
      final sesionId = vm.sesion!.id;

      final otro = otroRadar();
      expect(await otro.iniciar(curso, 'uid-docente'), isTrue);

      expect(otro.sesion!.id, sesionId);
      expect(cursos.sesionesPorCurso['c1']!.length, 1);
    });

    test('tras cerrar, el radar abre otro llamado en la misma franja',
        () async {
      final curso = cursoEnClase();
      await vm.iniciar(curso, 'uid-docente');
      final sesionId = vm.sesion!.id;
      final franja = vm.sesion!.franja;
      await vm.detener();

      final otro = otroRadar();
      expect(await otro.iniciar(curso, 'uid-docente'), isTrue);

      // Dos llamados, pero una sola clase: la asistencia cuenta por franja.
      expect(otro.sesion!.id, isNot(sesionId));
      expect(otro.sesion!.franja, franja);
      expect(cursos.sesionesPorCurso['c1']!.length, 2);
    });

    test('un llamado colgado y vencido se cierra y se abre otro', () async {
      final ahora = DateTime(2026, 10, 29, 9, 30);
      // Un llamado de hace veinte minutos que quedó abierto porque al docente
      // se le murió la app sin cerrarlo.
      cursos.sesionesPorCurso['c1'] = [
        Sesion(
          id: 'colgado',
          inicio: ahora.subtract(const Duration(minutes: 20)),
          fin: ahora.subtract(const Duration(minutes: 10)),
          bloqueInicio: DateTime(2026, 10, 29, 9, 25),
        ),
      ];
      final radar = otroRadar(reloj: () => ahora);

      expect(await radar.iniciar(cursoEnClase(ahora: ahora), 'uid-docente'),
          isTrue);

      expect(cursos.sesion('c1', 'colgado').abierta, isFalse);
      expect(radar.sesion!.id, isNot('colgado'));
      expect(cursos.sesionesPorCurso['c1']!.length, 2);
    });
  });

  group('asistencia por BLE', () {
    test('marca presente a quien se oye y deja al resto pendiente', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.detectados, 1);
      expect(vm.faltantes, 1);
      final ana = vm.lista.firstWhere((i) => i.inscrito.clave == '1117000000');
      expect(ana.detectado, isTrue);
      expect(ana.asistencia!.metodo, MetodoAsistencia.ble);
      expect(ana.asistencia!.estado, EstadoAsistencia.presente);
      expect(ana.rssi, -55);
    });

    test('a quien aun no ha firmado se le espera, sin dar error', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');
      // Asi responde el servidor cuando el estudiante todavia no firmo su
      // presencia: la regla exige que exista antes de aceptar la asistencia.
      cursos.fallo = const CursoException(
        'No se pudo registrar la asistencia: permiso denegado en la base de '
        'datos.',
        'permission-denied',
      );

      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.detectados, 0);
      expect(vm.esperandoFirma('1117000000'), isTrue);
      // Al docente no se le saca un error por esto: el celular del
      // estudiante sigue anunciandose y el siguiente anuncio lo reintenta.
      expect(vm.error, isNull);

      cursos.fallo = null;
      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.detectados, 1);
      expect(vm.esperandoFirma('1117000000'), isFalse);
    });

    test('otros errores del servidor si se le cuentan al docente', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');
      cursos.fallo = const CursoException(
        'No se pudo registrar la asistencia: sin conexion con la base de '
        'datos.',
        'unavailable',
      );

      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.error, contains('sin conexion'));
      expect(vm.esperandoFirma('1117000000'), isFalse);
    });

    test('ignora balizas que no son de sus inscritos', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('9999999999');
      await pumpEventQueue();

      expect(vm.detectados, 0);
    });

    test('oír dos veces al mismo no lo marca dos veces', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('1117000000');
      await pumpEventQueue();
      final primera = vm.lista.first.asistencia!.hora;
      ble.oir('1117000000', rssi: -70);
      await pumpEventQueue();

      expect(vm.detectados, 1);
      expect(vm.lista.first.asistencia!.hora, primera);
      expect(vm.lista.first.rssi, -70);
    });

    test('reconoce al inscrito por su correo aunque tenga cédula', () async {
      // El docente lo inscribió con los dos datos, pero el celular del
      // estudiante emite la huella de su correo.
      cursos.inscritosPorCurso['c1']!['1117000002'] = const Inscrito(
        cedula: '1117000002',
        email: 'lu.rojas@udla.edu.co',
        nombre: 'LUISA ROJAS',
      );
      await vm.iniciar(cursoEnClase(), 'uid-docente');

      ble.oir('lu.rojas@udla.edu.co');
      await pumpEventQueue();

      final luisa = vm.lista.firstWhere((i) => i.inscrito.clave == '1117000002');
      expect(luisa.detectado, isTrue);
    });

    test('dentro del llamado todos quedan presentes', () async {
      // Aunque la clase arrancó hace cuarenta minutos: lo que cuenta es la
      // ventana del llamado, no cuánto lleva la clase.
      final curso = cursoEnClase(empezoHace: const Duration(minutes: 40));
      await vm.iniciar(curso, 'uid-docente');

      ble.oir('1117000000');
      await pumpEventQueue();

      expect(vm.lista.first.asistencia!.estado, EstadoAsistencia.presente);
    });

    test('el llamado manual marca ausente a quien no vino', () async {
      await vm.iniciar(cursoEnClase(), 'uid-docente');
      final carlos = cursos.inscritosPorCurso['c1']!['ca.munoz@udla.edu.co']!;

      expect(await vm.marcarManual(carlos, presente: false), isTrue);

      final fila = vm.lista.firstWhere((i) => i.inscrito.clave == carlos.clave);
      expect(fila.asistencia!.estado, EstadoAsistencia.ausente);
      expect(fila.asistencia!.metodo, MetodoAsistencia.manual);
    });
  });

  test('detener cierra la sesión y apaga el escaneo', () async {
    await vm.iniciar(cursoEnClase(), 'uid-docente');
    final sesionId = vm.sesion!.id;

    await vm.detener();

    expect(vm.escaneando, isFalse);
    expect(ble.escaneando, isFalse);
    expect(vm.sesion, isNull);
    expect(cursos.sesion('c1', sesionId).abierta, isFalse);
  });
}
