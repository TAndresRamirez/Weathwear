import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/presentation/widgets/prenda_foto_tile.dart';

/// Prendas base de un outfit en fila, unidas por "+" (una sola si es entero),
/// y la capa exterior debajo si existe. Lo usan la recomendación y el detalle.
class OutfitPrendasView extends StatelessWidget {
  const OutfitPrendasView({
    super.key,
    required this.principales,
    this.exterior,
    this.size = 104,
  });

  final List<PrendaModel> principales;
  final PrendaModel? exterior;

  /// Tamaño máximo de cada foto; se reduce si la fila no cabe.
  final double size;

  // Ícono "+" (32) más su padding horizontal (12 + 12)
  static const double _anchoSigno = 56;

  @override
  Widget build(BuildContext context) {
    final capa = exterior; // variable local para que Dart promueva el nullable
    return LayoutBuilder(
      builder: (context, constraints) {
        // En el diálogo de outfit el ancho disponible es menor que 2 fotos de
        // [size] + el "+": se ajusta el lado para no desbordar la fila.
        final n = principales.length;
        final lado = constraints.hasBoundedWidth && n > 0
            ? math.min(size, (constraints.maxWidth - _anchoSigno * (n - 1)) / n)
            : size;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.add, size: 32),
                    ),
                  PrendaFotoTile(prenda: principales[i], size: lado),
                ],
              ],
            ),
            if (capa != null) ...[
              const SizedBox(height: 12),
              PrendaFotoTile(prenda: capa, size: lado),
            ],
          ],
        );
      },
    );
  }
}
