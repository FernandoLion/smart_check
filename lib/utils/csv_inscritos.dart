import '../models/inscrito_model.dart';

/// Resultado de leer una lista de estudiantes pegada desde Excel o un CSV.
class ResultadoCsv {
  final List<Inscrito> inscritos;

  /// Filas que no se pudieron leer, con su número de línea (desde 1).
  final List<String> errores;

  /// Título de la columna usada para cada dato, tal como venía en el
  /// encabezado (null si no hubo encabezado o no se encontró esa columna).
  final String? columnaCedula;
  final String? columnaNombre;
  final String? columnaCorreo;

  const ResultadoCsv(
    this.inscritos,
    this.errores, {
    this.columnaCedula,
    this.columnaNombre,
    this.columnaCorreo,
  });

  bool get conEncabezado =>
      columnaCedula != null || columnaNombre != null || columnaCorreo != null;
}

final _soloDigitos = RegExp(r'^\d{6,12}$');
final _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Sin encabezado, cada celda se reconoce por su forma. Con más columnas que
/// estas (código, fecha, teléfono...) ya no se puede saber cuál es cuál.
const _maxCeldasSinEncabezado = 4;

/// Lee estudiantes de un texto con una fila por estudiante, separado por
/// tabulaciones (copiado de Excel), punto y coma o comas.
///
/// Si la primera fila es un encabezado (DOCUMENTO, NOMBRECOMPLETO, MAIL_INST,
/// "Cédula", "Nombre", "Correo"...) se usan esas columnas y se ignoran las
/// demás. Si no, cada celda se reconoce por su forma: solo dígitos es la
/// cédula, con @ es el correo y el resto forma el nombre.
/// Se ignoran filas vacías y estudiantes repetidos.
ResultadoCsv parsearInscritos(String texto) {
  final lineas = texto
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .toList();
  final noVacias = lineas.where((l) => l.isNotEmpty).toList();
  if (noVacias.isEmpty) return const ResultadoCsv([], []);

  final separador = _detectarSeparador(noVacias.first);
  final encabezado = _celdas(noVacias.first, separador);
  final columnas = _columnasDeEncabezado(encabezado);
  if (columnas == null &&
      encabezado.where((c) => c.isNotEmpty).length > _maxCeldasSinEncabezado) {
    return const ResultadoCsv([], [
      'No se encontró la fila de títulos. Copia también la primera fila del '
          'Excel (DOCUMENTO, NOMBRECOMPLETO, MAIL_INST...).',
    ]);
  }

  final inscritos = <Inscrito>[];
  final vistos = <String>{};
  final errores = <String>[];
  var primeraNoVacia = true;

  for (var i = 0; i < lineas.length; i++) {
    final linea = lineas[i];
    if (linea.isEmpty) continue;
    if (primeraNoVacia) {
      primeraNoVacia = false;
      if (columnas != null) continue;
    }

    final celdas = _celdas(linea, separador);
    final inscrito = columnas != null
        ? _desdeColumnas(celdas, columnas)
        : _desdeFormas(celdas);
    if (inscrito == null) {
      errores.add('Línea ${i + 1}: falta la cédula o el correo.');
      continue;
    }
    if (inscrito.claves.any(vistos.contains)) continue;
    vistos.addAll(inscrito.claves);
    inscritos.add(inscrito);
  }
  String? titulo(int? i) => i == null ? null : encabezado[i];
  return ResultadoCsv(
    inscritos,
    errores,
    columnaCedula: titulo(columnas?.cedula),
    columnaNombre: titulo(columnas?.nombre),
    columnaCorreo: titulo(columnas?.correo),
  );
}

String _detectarSeparador(String linea) {
  if (linea.contains('\t')) return '\t';
  if (linea.contains(';')) return ';';
  return ',';
}

List<String> _celdas(String linea, String separador) => linea
    .split(separador)
    .map((c) => c.trim().replaceAll(RegExp(r'^"|"$'), '').trim())
    .toList();

/// Quita puntos, espacios y guiones: "1.117.000.000" -> "1117000000".
String _limpiarCedula(String valor) => valor.replaceAll(RegExp(r'[.\s-]'), '');

class _Columnas {
  final int? cedula;
  final int? nombre;
  final int? correo;
  const _Columnas(this.cedula, this.nombre, this.correo);
}

/// "Correo Institucional" -> "correoinstitucional", "MAIL_INST" -> "mailinst".
String _normalizarTitulo(String titulo) => titulo
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll(RegExp(r'[^a-zñ]'), '');

bool _esTituloCedula(String t) =>
    !t.contains('tipo') &&
    (t.contains('documento') ||
        t.contains('cedula') ||
        t.contains('identificacion') ||
        t == 'cc' ||
        t == 'id');

/// Qué tan probable es que la columna sea el nombre del estudiante (0: no).
/// "CODIGOESTUDIANTE" o "NOMBREPROGRAMA" no lo son.
int _puntajeNombre(String t) {
  if (t.contains('codigo') || t.contains('programa')) return 0;
  if (t.contains('nombre') &&
      (t.contains('completo') ||
          t.contains('apellido') ||
          t.contains('estudiante'))) {
    return 3;
  }
  if (t == 'nombre' || t == 'nombres' || t == 'estudiante' || t == 'alumno') {
    return 2;
  }
  return t.contains('nombre') ? 1 : 0;
}

_Columnas? _columnasDeEncabezado(List<String> celdas) {
  // Una fila con un correo o una cédula es de datos, no de títulos (aunque
  // un nombre como "Ismail" contenga "mail").
  final esDeDatos = celdas.any(
    (c) => c.contains('@') || _soloDigitos.hasMatch(_limpiarCedula(c)),
  );
  if (esDeDatos) return null;

  int? cedula, nombre, correo;
  var mejorNombre = 0;
  for (var i = 0; i < celdas.length; i++) {
    final t = _normalizarTitulo(celdas[i]);
    if (t.isEmpty) continue;
    if (_esTituloCedula(t)) {
      cedula ??= i;
    } else if (t.contains('correo') || t.contains('mail')) {
      // Si hay correo personal e institucional, se prefiere el institucional.
      final institucional = t.contains('inst');
      if (correo == null ||
          (institucional &&
              !_normalizarTitulo(celdas[correo]).contains('inst'))) {
        correo = i;
      }
    } else {
      final puntaje = _puntajeNombre(t);
      if (puntaje > mejorNombre) {
        mejorNombre = puntaje;
        nombre = i;
      }
    }
  }
  if (cedula == null && correo == null) return null;
  return _Columnas(cedula, nombre, correo);
}

Inscrito? _desdeColumnas(List<String> celdas, _Columnas col) {
  String? celda(int? i) =>
      i != null && i < celdas.length && celdas[i].isNotEmpty ? celdas[i] : null;

  final cedulaCruda = celda(col.cedula);
  final cedula = cedulaCruda == null ? null : _limpiarCedula(cedulaCruda);
  final correo = celda(col.correo)?.toLowerCase();
  return _crear(
    cedula: cedula != null && _soloDigitos.hasMatch(cedula) ? cedula : null,
    correo: correo != null && _correo.hasMatch(correo) ? correo : null,
    nombre: celda(col.nombre),
  );
}

Inscrito? _desdeFormas(List<String> celdas) {
  String? cedula, correo;
  final nombre = <String>[];
  for (final c in celdas) {
    if (c.isEmpty) continue;
    final limpia = _limpiarCedula(c);
    if (cedula == null && _soloDigitos.hasMatch(limpia)) {
      cedula = limpia;
    } else if (correo == null && _correo.hasMatch(c)) {
      correo = c.toLowerCase();
    } else {
      nombre.add(c);
    }
  }
  return _crear(
    cedula: cedula,
    correo: correo,
    nombre: nombre.isEmpty ? null : nombre.join(' '),
  );
}

final _letra = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]');

Inscrito? _crear({String? cedula, String? correo, String? nombre}) {
  if (cedula == null && correo == null) return null;
  // Un "nombre" sin letras (un código, un teléfono) no es un nombre.
  final valido = nombre != null && _letra.hasMatch(nombre) ? nombre : null;
  return Inscrito(
    cedula: cedula,
    email: correo,
    nombre: (valido ?? correo?.split('@').first ?? cedula!).toUpperCase(),
  );
}
