import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';

/// Fondo plano, adaptado al tema claro/oscuro.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.wColors.fondo, child: child);
}
