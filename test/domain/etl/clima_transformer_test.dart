import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_raw_models.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';

void main() {
  final transformer = ClimaTransformer();

  test('transforma un ClimaRawModels valido a ClimaModel', () {
    final raw = ClimaRawModels(
      timestamp: DateTime(2026, 9, 24, 15),
      temperature: 21.4,
      relativeHumidity: 36.0,
      weatherCode: 0,
    );

    final result = transformer.transform(raw);

    expect(result.temperatura, 21.4);
    expect(result.humedad, 36.0);
    expect(result.condicion, 'soleado');
    expect(result.fechaHora, DateTime(2026, 9, 24, 15));
  });

  test('lanza ArgumentError si weatherCode esta fuera de rango WMO', () {
    final raw = ClimaRawModels(
      timestamp: DateTime.now(),
      temperature: 20.0,
      relativeHumidity: 50.0,
      weatherCode: 150,
    );

    expect(() => transformer.transform(raw), throwsArgumentError);
  });
}
