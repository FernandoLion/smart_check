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
