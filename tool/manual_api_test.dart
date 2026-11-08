// ignore_for_file: avoid_print
// Prueba de humo manual contra la API real de Open-Meteo (no corre en CI).
// Uso: dart run tool/manual_api_test.dart
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';

//

Future<void> main() async {
  final apiClient = ClimaApiClient();

  try {
    final clima = await apiClient.fetchClimaActual();
    print('Extraccion exitosa');
    print('timestamp: ${clima.timestamp}');
    print('temperature: ${clima.temperature}');
    print('apparentTemperature: ${clima.apparentTermperature}');
    print('relativeHumidity: ${clima.relativeHumidity}');
    print('windSpeed: ${clima.windSpeed}');
    print('weatherCode: ${clima.weatherCode}');
  } on ClimaApiException catch (e) {
    print('Error controlado: $e');
  } finally {
    apiClient.dispose();
  }
}
