import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';

/// Fondo con degradado vertical, adaptado al tema claro/oscuro.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.wColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.fondoInicio, c.fondoFin],
        ),
      ),
      child: child,
    );
  }
}
