import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/data/models/prenda_model.dart';

/// Foto de una prenda que llena el espacio disponible, con esquinas redondeadas.
class PrendaImagen extends StatelessWidget {
  const PrendaImagen({super.key, required this.prenda, this.radius = 12});

  final PrendaModel prenda;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(prenda.imagenRuta),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // Si el archivo se borró, no rompe la grilla
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.checkroom_outlined, size: 32)),
      ),
    );
  }
}
