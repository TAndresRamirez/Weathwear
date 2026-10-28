import 'package:weathwear/data/models/ajustes.dart';

// Solo presentación: la BD, el motor y los rangos de prendas siguen en °C y km/h.

String formatearTemperatura(
  double celsius,
  UnidadTemperatura unidad, {
  int decimales = 1,
}) {
  final esF = unidad == UnidadTemperatura.fahrenheit;
  final valor = esF ? celsius * 9 / 5 + 32 : celsius;
  // round() en vez de toStringAsFixed(0): evita "-0" para valores como -0.4
  final texto = decimales == 0
      ? valor.round().toString()
      : valor.toStringAsFixed(decimales);
  return '$texto${esF ? '°F' : '°C'}';
}

/// "10–25°C": un solo símbolo al final, como en el pop-up de outfit.
String formatearRangoTemperatura(
  double minCelsius,
  double maxCelsius,
  UnidadTemperatura unidad,
) {
  final min = formatearTemperatura(minCelsius, unidad, decimales: 0);
  final max = formatearTemperatura(maxCelsius, unidad, decimales: 0);
  final simbolo = unidad == UnidadTemperatura.fahrenheit ? '°F' : '°C';
  return '${min.replaceAll(simbolo, '')}–$max';
}

String formatearViento(double kmh, UnidadViento unidad) {
  final esMph = unidad == UnidadViento.mph;
  final valor = esMph ? kmh * 0.621371 : kmh;
  return '${valor.round()} ${esMph ? 'mph' : 'km/h'}';
}
