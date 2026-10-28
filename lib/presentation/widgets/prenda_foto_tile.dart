import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/data/models/prenda_model.dart';

/// Cuadro con la foto de la prenda y su tipo debajo.
/// [sobrePanel] = true cuando el tile está dentro de una caja (panel/tarjeta):
/// el rótulo usa el texto oscuro de las cajas.
class PrendaFotoTile extends StatelessWidget {
  const PrendaFotoTile({
    super.key,
    required this.prenda,
    this.size = 104,
    this.sobrePanel = false,
  });

  final PrendaModel prenda;
  final double size;
  final bool sobrePanel;

  @override
  Widget build(BuildContext context) {
    final textos = sobrePanel ? context.panelText : Theme.of(context).textTheme;
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
            errorBuilder: (_, _, _) => Center(
              child: Icon(
                Icons.checkroom_outlined,
                size: 40,
                color: context.wColors.textoPanel,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          prenda.tipo,
          style: textos.labelMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
