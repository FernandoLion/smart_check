import '../models/verificacion_result_model.dart';
import '../utils/usuario_input_formatter.dart';

/// Interpreta la respuesta de VerificaCarne.aspx (Chairá).
///
/// La página es Ext.NET: al pulsar "Buscar" el servidor no devuelve HTML sino
/// un script que pinta los resultados, por ejemplo:
///
/// ```text
/// <textarea>{script:&quot;App.DFNombre.setText(\&quot;ANA PÉREZ\&quot;,true);...&quot;}</textarea>
/// ```
///
/// `consulta_carne.py` dejaba que un navegador ejecutara ese script y luego
/// leía el DOM (`#DFNombre-textEl`, `#DFCedula-textEl`...). Aquí se leen
/// directamente los valores de esas llamadas, sin navegador.
class ChairaParser {
  ChairaParser._();

  static const mensajeNoEncontrado =
      'No se encontraron registros para el documento proporcionado.';
  static const mensajeRespuestaInesperada =
      'Chairá devolvió una respuesta inesperada. Intenta de nuevo más tarde.';

  /// Textos de plantilla que muestran los controles antes de una búsqueda.
  static const _placeholders = {'NOMBRE', 'NÚMERO DOCUMENTO', 'PROGRAMA'};

  static final _textarea = RegExp(
    r'<textarea[^>]*>([\s\S]*?)</textarea>',
    caseSensitive: false,
  );
  static final _script = RegExp(r'''["']?script["']?\s*:\s*"((?:[^"\\]|\\.)*)"''');
  static final _setter = RegExp(
    r'App\.(\w+)\.(?:setText|setValue|setImageUrl)\(\s*"((?:[^"\\]|\\.)*)"',
  );
  static final _notificacion = RegExp(r'"html"\s*:\s*"((?:[^"\\]|\\.)*)"');
  static final _alerta = RegExp(
    r'Ext\.Msg\.alert\(\s*"(?:[^"\\]|\\.)*"\s*,\s*"((?:[^"\\]|\\.)*)"',
  );
  static final _errorServidor = RegExp(
    r'''["']?errorMessage["']?\s*:\s*"((?:[^"\\]|\\.)*)"''',
  );

  /// El campo donde logon.aspx deja el usuario. Ahí el setter viene sin el
  /// prefijo `App.` que sí usa VerificaCarne.
  static final _setterUsuario = RegExp(
    r'(?:App\.)?DF_Usuario\.setValue\(\s*"((?:[^"\\]|\\.)*)"',
  );

  /// Los campos ocultos que ASP.NET exige para aceptar un envío de
  /// logon.aspx: hay que leerlos de la página y devolvérselos tal cual.
  static final _oculto = RegExp(
    r'<input[^>]*name="(__VIEWSTATE|__VIEWSTATEGENERATOR|__EVENTVALIDATION)"'
    r'[^>]*value="([^"]*)"',
    caseSensitive: false,
  );

  static Map<String, String> camposOcultos(String html) => {
        for (final m in _oculto.allMatches(html))
          m.group(1)!: _decodeHtml(m.group(2)!),
      };

  /// El usuario institucional que responde `BuscarUsuario`, o null si Chairá
  /// no encontró a nadie con ese documento.
  ///
  /// La respuesta es del mismo estilo que la del carné, pero cuando no hay
  /// nadie el mensaje llega dentro del propio campo y en HTML:
  ///
  /// ```text
  /// {script:"...DF_Usuario.setValue(\"<FONT COLOR=red>No existe ningun
  /// usuario...</FONT>\");..."}
  /// ```
  ///
  /// Así que no basta con leer el campo: solo se acepta lo que tenga forma de
  /// usuario, y cualquier mensaje trae espacios y no la tiene.
  static String? usuarioDeRespuesta(String body) {
    final scriptMatch = _script.firstMatch(body);
    final script =
        scriptMatch != null ? _decodeJs(scriptMatch.group(1)!) : body;
    final match = _setterUsuario.firstMatch(script);
    if (match == null) return null;
    var usuario =
        _limpiar(_decodeHtml(_decodeJs(match.group(1)!))).toLowerCase();
    // Por si algún día devolviera el correo completo.
    final arroba = usuario.indexOf('@');
    if (arroba > 0) usuario = usuario.substring(0, arroba);
    return formatoUsuario.hasMatch(usuario) ? usuario : null;
  }

  static VerificacionResult parse(String documento, String body) {
    final textarea = _textarea.firstMatch(body);
    final contenido = textarea != null ? _decodeHtml(textarea.group(1)!) : body;

    final scriptMatch = _script.firstMatch(contenido);
    if (scriptMatch == null) {
      // Ext.NET responde {success:false,errorMessage:"..."} si la página falla.
      final errorServidor = _errorServidor.firstMatch(contenido);
      if (errorServidor != null) {
        return VerificacionResult.fallido(
          documento,
          _limpiar(_decodeJs(errorServidor.group(1)!)),
        );
      }
    }
    final script = scriptMatch != null ? _decodeJs(scriptMatch.group(1)!) : contenido;

    final valores = <String, String>{
      for (final m in _setter.allMatches(script))
        m.group(1)!: _limpiar(_decodeJs(m.group(2)!)),
    };

    String? valor(String control) {
      final v = valores[control];
      return (v == null || v.isEmpty || _placeholders.contains(v)) ? null : v;
    }

    final nombre = valor('DFNombre');
    if (nombre != null) {
      return VerificacionResult(
        success: true,
        documentoConsultado: documento,
        nombre: nombre,
        cedula: valor('DFCedula'),
        programa: valor('DFPrograma'),
        tipoUsuario: valor('LTipoUsuario'),
        fotoUrl: _urlFoto(valores['Image1']),
      );
    }

    final mensaje = _notificacion.firstMatch(script) ?? _alerta.firstMatch(script);
    if (mensaje != null) {
      final texto = _limpiar(_decodeHtml(_decodeJs(mensaje.group(1)!)));
      return VerificacionResult.fallido(
        documento,
        texto.isEmpty ? mensajeNoEncontrado : texto,
      );
    }

    return VerificacionResult.fallido(
      documento,
      valores.isEmpty ? mensajeRespuestaInesperada : mensajeNoEncontrado,
    );
  }

  /// Devuelve la URL (en https) de la foto, o null si la persona no tiene una.
  static String? _urlFoto(String? url) {
    if (url == null || url.isEmpty || url.contains('no_pic')) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.queryParameters.containsKey('mongoid') &&
        uri.queryParameters['mongoid']!.isEmpty) {
      return null;
    }
    return uri.replace(scheme: 'https').toString();
  }

  /// Quita etiquetas HTML y espacios sobrantes.
  static String _limpiar(String texto) => texto
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Deshace los escapes de un literal de texto JavaScript (\" \\ \n \u00C1...).
  static String _decodeJs(String texto) {
    return texto.replaceAllMapped(
      RegExp(r'\\(u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|[\s\S])'),
      (m) {
        final e = m.group(1)!;
        if (e.length > 1) {
          return String.fromCharCode(int.parse(e.substring(1), radix: 16));
        }
        switch (e) {
          case 'n':
            return '\n';
          case 't':
            return '\t';
          case 'r':
            return '\r';
          case 'b':
            return '\b';
          case 'f':
            return '\f';
          case 'v':
            return '\v';
          case '0':
            return '\x00';
          default:
            return e;
        }
      },
    );
  }

  static const _entidades = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'aacute': 'á',
    'eacute': 'é',
    'iacute': 'í',
    'oacute': 'ó',
    'uacute': 'ú',
    'Aacute': 'Á',
    'Eacute': 'É',
    'Iacute': 'Í',
    'Oacute': 'Ó',
    'Uacute': 'Ú',
    'ntilde': 'ñ',
    'Ntilde': 'Ñ',
    'uuml': 'ü',
    'Uuml': 'Ü',
  };

  /// Deshace las entidades HTML (&quot; &#193; &#xC1; &aacute;...).
  static String _decodeHtml(String texto) {
    return texto.replaceAllMapped(
      RegExp(r'&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);'),
      (m) {
        final e = m.group(1)!;
        if (e.startsWith('#')) {
          final hex = e.length > 1 && (e[1] == 'x' || e[1] == 'X');
          final code = int.tryParse(e.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
          return code == null ? m.group(0)! : String.fromCharCode(code);
        }
        return _entidades[e] ?? m.group(0)!;
      },
    );
  }
}
