import '../models/inscrito_model.dart';

/// Resultado de leer una lista de estudiantes pegada desde Excel o un CSV.
class ResultadoCsv {
  final List<Inscrito> inscritos;

  /// Filas que no se pudieron leer, con su número de línea (desde 1).
  final List<String> errores;

  const ResultadoCsv(this.inscritos, this.errores);
}

final _soloDigitos = RegExp(r'^\d{6,12}$');
final _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Lee estudiantes de un texto con una fila por estudiante, separado por
/// tabulaciones (copiado de Excel), punto y coma o comas.
///
/// Si la primera fila es un encabezado (cédula / documento, nombre, correo)
/// se usan sus columnas; si no, cada celda se reconoce por su forma: solo
/// dígitos es la cédula, con @ es el correo y el resto forma el nombre.
/// Se ignoran filas vacías y estudiantes repetidos.
ResultadoCsv parsearInscritos(String texto) {
  final lineas = texto
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .toList();
  final noVacias = lineas.where((l) => l.isNotEmpty).toList();
  if (noVacias.isEmpty) return const ResultadoCsv([], []);

  final separador = _detectarSeparador(noVacias.first);
  final columnas = _columnasDeEncabezado(_celdas(noVacias.first, separador));

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
  return ResultadoCsv(inscritos, errores);
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

_Columnas? _columnasDeEncabezado(List<String> celdas) {
  int? cedula, nombre, correo;
  for (var i = 0; i < celdas.length; i++) {
    final c = celdas[i].toLowerCase();
    if (c.contains('cédula') ||
        c.contains('cedula') ||
        c.contains('documento') ||
        c == 'cc' ||
        c == 'id') {
      cedula ??= i;
    } else if (c.contains('correo') || c.contains('email') || c.contains('mail')) {
      correo ??= i;
    } else if (c.contains('nombre') || c.contains('estudiante')) {
      nombre ??= i;
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

Inscrito? _crear({String? cedula, String? correo, String? nombre}) {
  if (cedula == null && correo == null) return null;
  return Inscrito(
    cedula: cedula,
    email: correo,
    nombre: (nombre ?? correo?.split('@').first ?? cedula!).toUpperCase(),
  );
}
