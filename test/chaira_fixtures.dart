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
/// tal como se comprobó contra el servidor. Dos cosas que no se ven en el
/// JavaScript del portal: el setter viene sin el prefijo `App.` del carné, y
/// el usuario llega envuelto en HTML de presentación, igual que el mensaje de
/// error, así que hay que limpiarlo antes de darlo por bueno.
String respuestaUsuario(String usuario) =>
    '{script:"Window1.hide();Window2.hide();Window3.show();'
    'DF_Usuario.setValue(\\"<BR/><BR/><FONT SIZE=6 COLOR=black>$usuario'
    '</FONT>\\");DF_Usuario.show();"}';

/// Y cuando no hay nadie con ese documento: el mensaje llega en el mismo
/// campo, en HTML y en rojo.
const respuestaUsuarioNoEncontrado =
    '{script:"Window1.hide();Window2.hide();Window3.show();'
    'DF_Usuario.setValue(\\"<FONT SIZE=3 COLOR=red>No existe ningun usuario '
    'registrado con el documento proporcionado.</FONT>\\");'
    'DF_Usuario.show();"}';
