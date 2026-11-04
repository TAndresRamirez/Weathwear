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
  final double size;

  @override
  Widget build(BuildContext context) {
    final capa = exterior; // variable local para que Dart promueva el nullable
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < principales.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.add, size: 32),
                ),
              PrendaFotoTile(prenda: principales[i], size: size),
            ],
          ],
        ),
        if (capa != null) ...[
          const SizedBox(height: 12),
          PrendaFotoTile(prenda: capa, size: size),
        ],
      ],
    );
  }
}
