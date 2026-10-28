import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/core/utils/formato_unidades.dart';
import 'package:weathwear/data/models/ajustes.dart';

void main() {
  test('temperatura: Celsius sin cambios y conversión a Fahrenheit', () {
    expect(formatearTemperatura(21.4, UnidadTemperatura.celsius), '21.4°C');
    expect(formatearTemperatura(0, UnidadTemperatura.fahrenheit), '32.0°F');
  });

  test('temperatura sin decimales no muestra "-0"', () {
    expect(
      formatearTemperatura(-0.4, UnidadTemperatura.celsius, decimales: 0),
      '0°C',
    );
  });

  test('rango lleva un solo símbolo y convierte ambos extremos', () {
    expect(
      formatearRangoTemperatura(10, 25, UnidadTemperatura.celsius),
      '10–25°C',
    );
    expect(
      formatearRangoTemperatura(10, 25, UnidadTemperatura.fahrenheit),
      '50–77°F',
    );
  });

  test('viento: km/h y mph', () {
    expect(formatearViento(100, UnidadViento.kmh), '100 km/h');
    expect(formatearViento(100, UnidadViento.mph), '62 mph');
  });
}
