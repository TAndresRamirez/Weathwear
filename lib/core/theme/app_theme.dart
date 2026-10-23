import 'package:flutter/material.dart';

/// Paleta propia de Weathwear (lo que Material no cubre: degradado, paneles, acento).
@immutable
class WeathwearColors extends ThemeExtension<WeathwearColors> {
  const WeathwearColors({
    required this.fondoInicio,
    required this.fondoFin,
    required this.panel,
    required this.tarjeta,
    required this.acento,
  });

  final Color fondoInicio; // degradado del fondo (arriba)
  final Color fondoFin; // degradado del fondo (abajo)
  final Color panel; // contenedores grandes (gris azulado claro)
  final Color tarjeta; // cuadros internos (gris más oscuro)
  final Color acento; // cian del cuadro "Datos"

  // Hex estimados a ojo desde los mockups; se ajustan en un solo lugar.
  static const claro = WeathwearColors(
    fondoInicio: Color(0xFFD3EBE2),
    fondoFin: Color(0xFFE6F2EE),
    panel: Color(0xFFCAD0DA),
    tarjeta: Color(0xFF9BA2AC),
    acento: Color(0xFF5CE1E6),
  );

  static const oscuro = WeathwearColors(
    fondoInicio: Color(0xFF14211D),
    fondoFin: Color(0xFF1F302A),
    panel: Color(0xFF2B323B),
    tarjeta: Color(0xFF414A55),
    acento: Color(0xFF2FA9AE),
  );

  @override
  WeathwearColors copyWith({
    Color? fondoInicio,
    Color? fondoFin,
    Color? panel,
    Color? tarjeta,
    Color? acento,
  }) => WeathwearColors(
    fondoInicio: fondoInicio ?? this.fondoInicio,
    fondoFin: fondoFin ?? this.fondoFin,
    panel: panel ?? this.panel,
    tarjeta: tarjeta ?? this.tarjeta,
    acento: acento ?? this.acento,
  );

  @override
  WeathwearColors lerp(ThemeExtension<WeathwearColors>? other, double t) {
    if (other is! WeathwearColors) return this;
    return WeathwearColors(
      fondoInicio: Color.lerp(fondoInicio, other.fondoInicio, t)!,
      fondoFin: Color.lerp(fondoFin, other.fondoFin, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      tarjeta: Color.lerp(tarjeta, other.tarjeta, t)!,
      acento: Color.lerp(acento, other.acento, t)!,
    );
  }
}

extension WeathwearThemeX on BuildContext {
  /// Paleta del tema actual. Si el tema no registra la extensión (tests o
  /// previews con un MaterialApp pelado), cae a la paleta según el brillo.
  WeathwearColors get wColors {
    final theme = Theme.of(this);
    return theme.extension<WeathwearColors>() ??
        (theme.brightness == Brightness.dark
            ? WeathwearColors.oscuro
            : WeathwearColors.claro);
  }
}

class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(
    Brightness.light,
    WeathwearColors.claro,
  );
  static final ThemeData dark = _build(Brightness.dark, WeathwearColors.oscuro);

  static ThemeData _build(Brightness brightness, WeathwearColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.acento,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [c],
      // Los paneles de las pantallas actuales (Card) toman el gris azulado
      cardTheme: CardThemeData(
        color: c.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: c.panel,
        indicatorColor: c.tarjeta, // el gris redondeado del ícono activo
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 32, color: scheme.onSurface),
        ),
      ),
    );
  }
}
