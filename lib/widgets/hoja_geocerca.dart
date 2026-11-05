import 'package:flutter/material.dart';

import '../models/curso_model.dart';
import '../utils/app_theme.dart';

/// Hoja para marcar dónde queda el aula y con cuánto margen.
class HojaGeocerca extends StatefulWidget {
  final Geocerca? geocerca;
  final Future<void> Function(double radio) alMarcar;
  final VoidCallback alQuitar;

  const HojaGeocerca({
    super.key,
    required this.geocerca,
    required this.alMarcar,
    required this.alQuitar,
  });

  @override
  State<HojaGeocerca> createState() => _HojaGeocercaState();
}

class _HojaGeocercaState extends State<HojaGeocerca> {
  static const _radios = [15.0, 25.0, 50.0, 100.0];

  late double _radio = widget.geocerca?.radioMetros ?? 25;
  bool _marcando = false;

  @override
  Widget build(BuildContext context) {
    final geocerca = widget.geocerca;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Geocerca del aula',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Párate en el aula y marca el punto. El radar solo abrirá la '
            'clase si estás dentro de este radio.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'RADIO',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _radios
                .map(
                  (r) => ChoiceChip(
                    label: Text('${r.round()} m'),
                    selected: _radio == r,
                    onSelected: (_) => setState(() => _radio = r),
                  ),
                )
                .toList(),
          ),
          if (geocerca != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.my_location,
                  color: Color(0xFF47E266),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Marcada en ${geocerca.latitud.toStringAsFixed(5)}, '
                    '${geocerca.longitud.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _marcando ? null : _marcar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E5CE6),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _marcando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      geocerca == null
                          ? 'Usar mi ubicación actual'
                          : 'Volver a marcar aquí',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (geocerca != null)
            TextButton(
              onPressed: () {
                widget.alQuitar();
                Navigator.pop(context);
              },
              child: const Text(
                'Quitar la geocerca',
                style: TextStyle(color: Color(0xFFFF453A)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _marcar() async {
    setState(() => _marcando = true);
    await widget.alMarcar(_radio);
    if (mounted) Navigator.pop(context);
  }
}
