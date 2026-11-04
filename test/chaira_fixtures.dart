// Respuestas con el mismo formato que devuelve VerificaCarne.aspx (Ext.NET),
// pero con datos inventados.

const fotoUrlHttp =
    'http://chaira.uniamazonia.edu.co/Administrativo/Vistas/Privado/TalentoHumano/FotoPerfil/Fotos.aspx?mongoid=abc123';

String respuestaExito({
  String mongoid = 'abc123',
  String tipo = 'ESTUDIANTE',
}) =>
    '<textarea>{script:&quot;'
    'App.Image1.setImageUrl(\\&quot;http://chaira.uniamazonia.edu.co/Administrativo/Vistas/Privado/TalentoHumano/FotoPerfil/Fotos.aspx?mongoid=$mongoid\\&quot;);'
    'App.DFNombre.setText(\\&quot;ANA MAR&#205;A P&#201;REZ G&#211;MEZ\\&quot;,true);'
    'App.DFCedula.setText(\\&quot;1117000000\\&quot;,true);'
    'App.LTipoUsuario.setText(\\&quot;$tipo\\&quot;,true);'
    'App.DFPrograma.setText(\\&quot;INGENIER&#205;A DE SISTEMAS\\&quot;,true);'
    '&quot;}</textarea>';

const respuestaNoEncontrado =
    '<textarea>{script:&quot;Ext.net.ResourceMgr.registerIcon(\\&quot;Information\\&quot;);'
    'Ext.net.Notification.show({\\&quot;title\\&quot;:\\&quot;Error\\&quot;,'
    '\\&quot;html\\&quot;:\\&quot;No fue posible encontrar una persona asociada a ese par&#225;metro\\&quot;,'
    '\\&quot;width\\&quot;:420,\\&quot;autoScroll\\&quot;:true,'
    '\\&quot;bodyStyle\\&quot;:\\&quot; text-align: left;padding:10px;\\&quot;,'
    '\\&quot;iconCls\\&quot;:\\&quot;#Information\\&quot;,\\&quot;showPin\\&quot;:true});&quot;}</textarea>';

/// La página de ingreso, con los campos ocultos que ASP.NET exige para
/// aceptar un envío.
const paginaLogon = '<html><body><form method="post" action="./logon.aspx">'
    '<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" '
    'value="N4MAS88ZZWI9" />'
    '<input type="hidden" name="__VIEWSTATEGENERATOR" '
    'id="__VIEWSTATEGENERATOR" value="1373A9E7" />'
    '<input type="hidden" name="__EVENTVALIDATION" id="__EVENTVALIDATION" '
    'value="m7/U/3T5gCXt" />'
    '</form></body></html>';

/// Lo que responde el DirectMethod `BuscarUsuario` cuando encuentra a alguien,
/// copiado byte a byte del servidor el 4 de noviembre de 2026 (con otro
/// usuario). El usuario viene en un SweetAlert, envuelto en HTML y con los
/// `<`, `>` y `'` escapados como `\u003c`... dentro de un literal que a su
/// vez va dentro del script: dos capas de JavaScript antes de llegar a él.
String respuestaUsuario(String usuario) =>
    r'''{script:"Window1.hide();swal({ title: 'Su usuario es', text: '''
    r"""'\\u003cb style=\\u0027color: #e07a1f; font-size: 1.2rem; """
    r"""font-weight: 600\\u0027\\u003e"""
    '$usuario'
    r"""\\u003c/b\\u003e', html: true, type: 'success', """
    r"""confirmButtonColor: '#186121', confirmButtonText: 'Aceptar' });"}""";

/// Y cuando no hay nadie con ese documento: el mismo aviso, de tipo error.
const respuestaUsuarioNoEncontrado =
    r'''{script:"Window1.hide();swal({ title: 'No encontrado', text: '''
    r"""'No existe ningun usuario registrado con el documento """
    r"""proporcionado.', html: true, type: 'error', """
    r"""confirmButtonColor: '#b3261e', confirmButtonText: 'Aceptar' });"}""";

/// El formato que tuvo `BuscarUsuario` hasta octubre de 2026: el usuario
/// escrito en el campo `DF_Usuario`, sin el prefijo `App.` del carné.
String respuestaUsuarioAnterior(String usuario) =>
    '{script:"Window1.hide();Window2.hide();Window3.show();'
    'DF_Usuario.setValue(\\"<BR/><BR/><FONT SIZE=6 COLOR=black>$usuario'
    '</FONT>\\");DF_Usuario.show();"}';

/// Y el "no encontrado" de entonces, en el mismo campo, en HTML y en rojo.
const respuestaUsuarioNoEncontradoAnterior =
    '{script:"Window1.hide();Window2.hide();Window3.show();'
    'DF_Usuario.setValue(\\"<FONT SIZE=3 COLOR=red>No existe ningun usuario '
    'registrado con el documento proporcionado.</FONT>\\");'
    'DF_Usuario.show();"}';
