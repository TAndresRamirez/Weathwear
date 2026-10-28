import 'package:flutter/material.dart';

/// Paleta propia de Weathwear (lo que Material no cubre: fondo, cajas, acento).
@immutable
class WeathwearColors extends ThemeExtension<WeathwearColors> {
  const WeathwearColors({
    required this.fondo,
    required this.panel,
    required this.tarjeta,
    required this.acento,
    required this.textoPanel,
  });

  final Color fondo; // fondo plano de las pantallas
  final Color panel; // cajas grandes
  final Color tarjeta; // cajas internas (un tono más oscuro que el panel)
  final Color acento; // cian del cuadro "Datos"
  final Color
  textoPanel; // texto e íconos sobre panel/tarjeta (oscuro en ambos temas)

  static const claro = WeathwearColors(
    fondo: Color(0xFF38B6FF),
    panel: Color(0xFFC8D1D9),
    tarjeta: Color(0xFFA8B2BD),
    acento: Color(0xFF5CE1E6),
    textoPanel: Color(0xFF1C1C1E),
  );

  static const oscuro = WeathwearColors(
    fondo: Color(0xFF004E7A),
    panel: Color(0xFFA6A6A6),
    tarjeta: Color(0xFF8C8C8C),
    acento: Color(0xFF2FA9AE),
    textoPanel: Color(0xFF1C1C1E),
  );

  @override
  WeathwearColors copyWith({
    Color? fondo,
    Color? panel,
    Color? tarjeta,
    Color? acento,
    Color? textoPanel,
  }) => WeathwearColors(
    fondo: fondo ?? this.fondo,
    panel: panel ?? this.panel,
    tarjeta: tarjeta ?? this.tarjeta,
    acento: acento ?? this.acento,
    textoPanel: textoPanel ?? this.textoPanel,
  );

  @override
  WeathwearColors lerp(ThemeExtension<WeathwearColors>? other, double t) {
    if (other is! WeathwearColors) return this;
    return WeathwearColors(
      fondo: Color.lerp(fondo, other.fondo, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      tarjeta: Color.lerp(tarjeta, other.tarjeta, t)!,
      acento: Color.lerp(acento, other.acento, t)!,
      textoPanel: Color.lerp(textoPanel, other.textoPanel, t)!,
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

  /// TextTheme para texto que se dibuja SOBRE una caja (panel/tarjeta).
  /// En modo oscuro el texto del tema es claro y no se lee sobre #a6a6a6.
  TextTheme get panelText {
    final c = wColors.textoPanel;
    return Theme.of(this).textTheme.apply(bodyColor: c, displayColor: c);
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
      // Los paneles de las pantallas actuales (Card) toman el color de caja
      cardTheme: CardThemeData(
        color: c.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: c.panel,
        indicatorColor: c.tarjeta, // el redondeado del ícono activo
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        // La barra es una caja: íconos oscuros en ambos temas
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 32, color: c.textoPanel),
        ),
      ),
    );
  }
}
