import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_check/models/asistencia_resumen.dart';
import 'package:smart_check/models/curso_model.dart';
import 'package:smart_check/models/inscrito_model.dart';
import 'package:smart_check/models/sesion_model.dart';
import 'package:smart_check/models/student_subject_model.dart';
import 'package:smart_check/models/usuario_perfil_model.dart';
import 'package:smart_check/utils/app_theme.dart';
import 'package:smart_check/utils/escala_texto.dart';
import 'package:smart_check/viewmodels/auth_viewmodel.dart';
import 'package:smart_check/viewmodels/beacon_viewmodel.dart';
import 'package:smart_check/viewmodels/course_detail_viewmodel.dart';
import 'package:smart_check/viewmodels/radar_viewmodel.dart';
import 'package:smart_check/viewmodels/student_viewmodel.dart';
import 'package:smart_check/viewmodels/teacher_viewmodel.dart';
import 'package:smart_check/views/attendance/attendance_radar_screen.dart';
import 'package:smart_check/views/attendance/ble_beacon_screen.dart';
import 'package:smart_check/views/attendance/face_verification_screen.dart';
import 'package:smart_check/views/attendance/manual_rollcall_screen.dart';
import 'package:smart_check/views/login_screen.dart';
import 'package:smart_check/views/recover_password_screen.dart';
import 'package:smart_check/views/smart_register_screen.dart';
import 'package:smart_check/views/student/attendance_detail_screen.dart';
import 'package:smart_check/views/student/biometric_validation_screen.dart';
import 'package:smart_check/views/student/student_home_screen.dart';
import 'package:smart_check/views/student/student_settings_screen.dart';
import 'package:smart_check/views/teacher/add_student_screen.dart';
import 'package:smart_check/views/teacher/course_detail_screen.dart';
import 'package:smart_check/views/teacher/create_course_screen.dart';
import 'package:smart_check/views/teacher/import_csv_screen.dart';
import 'package:smart_check/views/teacher/session_detail_screen.dart';
import 'package:smart_check/views/teacher/teacher_home_screen.dart';
import 'package:smart_check/views/teacher/teacher_settings_screen.dart';
import 'package:smart_check/widgets/hoja_clase_extra.dart';

import 'auth_fakes.dart';
import 'ble_fakes.dart';
import 'curso_fakes.dart';

/// Que ninguna pantalla se desborde en teléfonos angostos ni con la letra
/// grande del sistema.
///
/// Abre cada pantalla con datos de prueba largos en varios tamaños de
/// teléfono y escalas de letra, y falla si Flutter avisa de un desborde (las
/// franjas amarillas y negras). Usa Roboto, la letra real de Android: la de
/// los tests por defecto es mucho más ancha y daría falsas alarmas.

/// Un teléfono y una escala de letra.
class _Pantalla {
  final String nombre;
  final Size tamano;
  final double letra;
  const _Pantalla(this.nombre, this.tamano, this.letra);
}

const _pantallas = [
  // 320 dp de ancho: el Huawei del proyecto con la pantalla ampliada.
  _Pantalla('320×640, letra normal', Size(320, 640), 1.0),
  // La escala máxima que respeta la app (ver escala_texto.dart). El Xiaomi
  // de pruebas tiene la letra al 140 %, que la app recorta a esto.
  _Pantalla('320×640, letra máxima', Size(320, 640), escalaMaximaDeTexto),
  _Pantalla('360×740, letra del Xiaomi', Size(360, 740), 1.4),
  // Un teléfono pequeño y bajo.
  _Pantalla('320×568, letra normal', Size(320, 568), 1.0),
  // Muy alta, para que se dibuje también lo que queda debajo del pliegue.
  _Pantalla(
    '320 de ancho, todo el contenido',
    Size(320, 4000),
    escalaMaximaDeTexto,
  ),
];

const _correo = 'an.perez@udla.edu.co';
const _uid = 'uid-$_correo';
const _cedula = '1117000001';

/// Datos largos a propósito: un nombre de materia y de docente reales de los
/// que más ocupan.
Curso _curso({String id = 'c1'}) {
  final base = cursoEnClase(id: id);
  return Curso(
    id: id,
    codigo: 'SIS-402-AV',
    nombre: 'Arquitectura de Software Empresarial Avanzada',
    grupo: '302-B',
    aula: 'Bloque Ciencias Básicas • Aula 204',
    periodo: '2026-2',
    docenteUid: _uid,
    docenteNombre: 'MARÍA FERNANDA RODRÍGUEZ VALENCIA',
    horarios: base.horarios,
    clavesInscritos: const [_cedula, _correo],
    totalInscritos: 2,
  );
}

const _inscritos = {
  _cedula: Inscrito(
    cedula: _cedula,
    email: _correo,
    nombre: 'ANA MARÍA PÉREZ GÓMEZ DE LA TORRE',
  ),
  '1117000002': Inscrito(
    cedula: '1117000002',
    nombre: 'CARLOS ANDRÉS MUÑOZ RIVERA',
  ),
};

/// Todo lo que las pantallas leen de los providers, con servicios falsos.
class _Mundo {
  final cursos = FakeCursoService();
  late final AuthViewModel auth;
  late final StudentViewModel estudiante;
  late final TeacherViewModel docente;

  Future<void> preparar() async {
    final curso = _curso();
    cursos.cursos[curso.id] = curso;
    cursos.inscritosPorCurso[curso.id] = Map.of(_inscritos);
    final ahora = DateTime.now();
    cursos.sesionesPorCurso[curso.id] = [
      Sesion(
        id: 's1',
        inicio: ahora.subtract(const Duration(days: 7)),
        fin: ahora.subtract(const Duration(days: 7)).add(
              const Duration(minutes: 10),
            ),
        abierta: false,
      ),
    ];

    final authService = FakeAuthService()..cuentas[_correo] = 'Clave123!';
    final perfiles = FakePerfilService()
      ..perfiles[_uid] = perfilDe(
        _correo,
        'ANA MARÍA PÉREZ GÓMEZ DE LA TORRE',
        [Rol.docente, Rol.estudiante],
      );
    auth = AuthViewModel(
      authService: authService,
      perfilService: perfiles,
      chairaService: chairaFalso(),
      dispositivos: FakeDispositivoService(),
    );
    await auth.signIn('an.perez', 'Clave123!');
    // Con el celular ya vinculado, como el de un estudiante que ya marca
    // asistencia: así se dibujan los textos de ese estado.
    await auth.vincularEsteDispositivo();
    estudiante = StudentViewModel(servicio: cursos);
    docente = TeacherViewModel(servicio: cursos);
  }

  Widget envolver(Widget pantalla) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: estudiante),
          ChangeNotifierProvider.value(value: docente),
        ],
        child: MaterialApp(
          theme: _conRoboto(AppTheme.darkTheme),
          builder: limitarEscalaDeTexto,
          home: pantalla,
        ),
      );

  RadarViewModel radar() => RadarViewModel(
        cursos: cursos,
        ble: FakeBleService(),
        ubicacion: FakeUbicacionService(),
      );
}

/// En el celular, el texto sin familia usa la letra del sistema (Roboto); en
/// los tests usaría la cuadrada de pruebas.
ThemeData _conRoboto(ThemeData tema) {
  final boton = tema.elevatedButtonTheme.style;
  final letraBoton = boton?.textStyle?.resolve({});
  return tema.copyWith(
    textTheme: tema.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: tema.primaryTextTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: boton?.copyWith(
        textStyle: WidgetStatePropertyAll(
          (letraBoton ?? const TextStyle()).copyWith(fontFamily: 'Roboto'),
        ),
      ),
    ),
  );
}

/// Cada pantalla de la app, con lo que necesita para abrirse.
final Map<String, Future<Widget> Function(_Mundo)> _vistas = {
  'Inicio de sesión': (_) async => const LoginScreen(),
  'Registro': (_) async => const SmartRegisterScreen(),
  'Recuperar contraseña': (_) async => const RecoverPasswordScreen(),
  'Portal del estudiante': (_) async => const StudentHomeScreen(),
  'Ajustes del estudiante': (_) async => const StudentSettingsScreen(),
  'Detalle de materia': (m) async => AttendanceDetailScreen(
        subject: StudentSubjectModel.desdeCurso(
          _curso(),
          asistencia: const AsistenciaResumen(sesiones: 12, asistidas: 9),
        ),
      ),
  'Celular vinculado': (_) async => const BiometricValidationScreen(),
  'Verificación facial': (m) async => FaceVerificationScreen(curso: _curso()),
  'Baliza del estudiante': (m) async => BleBeaconScreen(
        cursos: [_curso()],
        clave: _cedula,
        vm: BeaconViewModel(
          cursos: m.cursos,
          ble: FakeBleService(),
          ubicacion: FakeUbicacionService(),
          dispositivos: FakeDispositivoService(),
        ),
      ),
  'Panel docente': (_) async => const TeacherHomeScreen(),
  'Ajustes del docente': (_) async => const TeacherSettingsScreen(),
  'Crear curso': (_) async => const CreateCourseScreen(),
  'Programar clase extra': (_) async => Scaffold(
        backgroundColor: AppTheme.surfaceElevated,
        body: SafeArea(
          child: HojaClaseExtra(
            curso: _curso(),
            ahora: DateTime(2026, 11, 19, 10),
          ),
        ),
      ),
  'Añadir estudiante': (_) async => const AddStudentScreen(
        courseTitle: 'Arquitectura de Software Empresarial Avanzada',
      ),
  'Importar CSV': (_) async => const ImportCsvScreen(
        courseName: 'Arquitectura de Software Empresarial Avanzada',
      ),
  'Detalle del curso': (m) async => CourseDetailScreen(
        curso: _curso(),
        vm: CourseDetailViewModel(servicio: m.cursos),
      ),
  'Detalle de sesión': (m) async {
    final sesion = m.cursos.sesionesPorCurso[_curso().id]!.first;
    // Uno vino (por el radar) y el otro no: las dos filas a la vez.
    m.cursos.asistenciasPorSesion[sesion.id] = [
      Asistencia(
        claveInscrito: _cedula,
        estado: EstadoAsistencia.presente,
        metodo: MetodoAsistencia.ble,
        hora: sesion.inicio.add(const Duration(minutes: 3)),
        registradoPor: _uid,
      ),
    ];
    return SessionDetailScreen(
      curso: _curso(),
      vm: CourseDetailViewModel(servicio: m.cursos)..vigilar(_curso().id),
      franja: sesion.franja,
      fechaTitulo: 'Miércoles 28 de octubre de 2026',
      horario: 'Llamado 08:02 - 08:12',
    );
  },
  'Radar': (m) async => AttendanceRadarScreen(curso: _curso(), vm: m.radar()),
  'Llamado manual': (m) async {
    final radar = m.radar();
    await radar.iniciar(_curso(), _uid);
    return ManualRollcallScreen(radar: radar);
  },
};

Future<void> _cargarFuentes() async {
  final carpeta = _carpetaDeFuentes();
  Future<void> cargar(String familia, List<String> archivos) async {
    final cargador = FontLoader(familia);
    for (final archivo in archivos) {
      final bytes = File('${carpeta.path}/$archivo').readAsBytesSync();
      cargador.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await cargador.load();
  }

  const roboto = [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-light.ttf',
    'roboto-black.ttf',
    'roboto-italic.ttf',
  ];
  await cargar('Roboto', roboto);
  // `monospace` en Android es una letra de ancho fijo parecida en tamaño.
  await cargar('monospace', ['roboto-regular.ttf']);
  await cargar('MaterialIcons', ['materialicons-regular.otf']);
}

/// Las fuentes de Material vienen con el SDK de Flutter, junto al ejecutable
/// que corre los tests.
Directory _carpetaDeFuentes() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    for (final sub in [
      'material_fonts',
      'artifacts/material_fonts',
      'cache/artifacts/material_fonts',
      'bin/cache/artifacts/material_fonts',
    ]) {
      final candidata = Directory('${dir.path}/$sub');
      if (candidata.existsSync()) return candidata;
    }
    dir = dir.parent;
  }
  throw StateError('No se encontraron las fuentes de Material del SDK.');
}

final _letra = RegExp(r'\p{L}', unicode: true);

/// Textos de varias líneas en los que un salto cae a mitad de palabra
/// ("Termómetr / o"): pasa cuando una palabra no cabe en el ancho que le
/// queda. No es un desbordamiento, pero se ve roto.
List<String> _palabrasPartidas(WidgetTester tester) {
  final partidas = <String>[];
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (!p.hasSize || p.size.width <= 0) continue;
    final texto = p.text.toPlainText();
    if (!texto.contains(_letra)) continue;
    final painter = TextPainter(
      text: p.text,
      textDirection: p.textDirection,
      textAlign: p.textAlign,
      textScaler: p.textScaler,
      maxLines: p.maxLines,
      locale: p.locale,
      strutStyle: p.strutStyle,
      textWidthBasis: p.textWidthBasis,
    )..layout(maxWidth: p.constraints.maxWidth);
    final lineas = painter.computeLineMetrics();
    var inicio = 0;
    for (var i = 0; i < lineas.length - 1; i++) {
      final limite = painter.getLineBoundary(TextPosition(offset: inicio));
      final fin = limite.end;
      if (fin <= 0 || fin >= texto.length) break;
      if (_letra.hasMatch(texto[fin - 1]) && _letra.hasMatch(texto[fin])) {
        partidas.add('"${texto.substring(0, fin)}|${texto.substring(fin)}"');
        break;
      }
      inicio = fin;
    }
    painter.dispose();
  }
  return partidas;
}

/// Las fuentes se cargan una vez, dentro del primer test: fuera de uno, el
/// motor de pruebas no las registra.
var _fuentesCargadas = false;

void main() {

  for (final pantalla in _pantallas) {
    group(pantalla.nombre, () {
      for (final vista in _vistas.entries) {
        testWidgets(vista.key, (tester) async {
          tester.view.physicalSize = pantalla.tamano;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = pantalla.letra;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final desbordes = <String>[];
          final palabrasPartidas = <String>[];
          final original = FlutterError.onError;
          FlutterError.onError = (detalles) {
            final texto = detalles.exceptionAsString();
            if (texto.contains('overflowed')) {
              // Dónde está el widget que se desborda (archivo:línea).
              final donde = RegExp(r'lib/views/[^\s:]+\.dart:\d+')
                  .firstMatch(detalles.toString())
                  ?.group(0);
              desbordes.add('${texto.split('\n').first} ${donde ?? ''}'.trim());
              // Con DETALLE_DESBORDES=1 se imprime todo, para depurar.
              if (Platform.environment['DETALLE_DESBORDES'] == '1') {
                debugPrint(detalles.toString());
              }
              return;
            }
            original?.call(detalles);
          };

          try {
            if (!_fuentesCargadas) {
              await tester.runAsync(_cargarFuentes);
              _fuentesCargadas = true;
            }
            final mundo = _Mundo();
            await tester.runAsync(mundo.preparar);
            final widget = await tester.runAsync(() => vista.value(mundo));
            await tester.pumpWidget(mundo.envolver(widget!));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(seconds: 1));
            palabrasPartidas.addAll(_palabrasPartidas(tester));
            // Se cierra todo para que no queden animaciones ni temporizadores.
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 3));
          } finally {
            FlutterError.onError = original;
          }

          expect(
            desbordes.toSet().toList(),
            isEmpty,
            reason: '${vista.key} se desborda en ${pantalla.nombre}',
          );
          expect(
            palabrasPartidas.toSet().toList(),
            isEmpty,
            reason: '${vista.key} parte palabras en ${pantalla.nombre}',
          );
        });
      }
    });
  }
}
