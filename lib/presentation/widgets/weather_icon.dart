import 'package:flutter/material.dart';

/// Ícono a color según la condición (assets/icons/weather/<condicion>.png).
/// Si falta el archivo, cae a un ícono Material para no romper la pantalla.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.condicion, required this.size});

  final String condicion;
  final double size;

  static String _asset(String c) =>
      'assets/icons/weather/${c.replaceAll(' ', '_')}.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset(condicion),
      width: size,
      height: size,
      semanticLabel: condicion,
      errorBuilder: (_, _, _) => Icon(Icons.wb_cloudy_outlined, size: size),
    );
  }
}
