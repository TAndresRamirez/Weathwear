import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/data/models/prenda_model.dart';

/// Cuadro con la foto de la prenda y su tipo debajo.
class PrendaFotoTile extends StatelessWidget {
  const PrendaFotoTile({super.key, required this.prenda, this.size = 104});

  final PrendaModel prenda;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.wColors.tarjeta,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(prenda.imagenRuta),
            fit: BoxFit.cover,
            // Si el archivo se borró, no rompe la pantalla
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.checkroom_outlined, size: 40)),
          ),
        ),
        const SizedBox(height: 4),
        Text(prenda.tipo, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
