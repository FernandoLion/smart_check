import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/fotos_chaira.dart';

/// La foto del carné de Chairá en un círculo, o [enSuLugar] mientras no
/// está o si no hay (las iniciales, un ícono). La foto se baja una vez y
/// después se lee del celular ([FotosChaira]).
class FotoDeChaira extends StatefulWidget {
  final String? url;
  final double diametro;
  final Widget enSuLugar;

  /// Solo para las pruebas.
  final FotosChaira? fotos;

  const FotoDeChaira({
    super.key,
    required this.url,
    required this.diametro,
    required this.enSuLugar,
    this.fotos,
  });

  @override
  State<FotoDeChaira> createState() => _FotoDeChairaState();
}

class _FotoDeChairaState extends State<FotoDeChaira> {
  Uint8List? _foto;

  FotosChaira get _fotos => widget.fotos ?? FotosChaira.compartida;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(FotoDeChaira antes) {
    super.didUpdateWidget(antes);
    if (antes.url != widget.url) {
      _foto = null;
      _cargar();
    }
  }

  void _cargar() {
    final url = widget.url;
    if (url == null || url.isEmpty) return;
    // Si ya está en memoria se pinta de una vez, sin parpadeo.
    _foto = _fotos.enMemoria(url);
    if (_foto != null) return;
    _fotos.foto(url).then((bytes) {
      if (mounted && bytes != null && widget.url == url) {
        setState(() => _foto = bytes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    return SizedBox.square(
      dimension: widget.diametro,
      child: foto == null
          ? widget.enSuLugar
          : ClipOval(
              child: Image.memory(
                foto,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // Si los bytes no son una imagen, lo de siempre.
                errorBuilder: (_, _, _) => widget.enSuLugar,
              ),
            ),
    );
  }
}
