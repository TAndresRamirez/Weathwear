// ignore_for_file: avoid_print
// Prueba de humo manual contra la API real de Open-Meteo (no corre en CI).
// Uso: dart run tool/manual_api_test.dart
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';
import 'package:weathwear/data/models/clima_raw_models.dart';

Future<void> main() async {
  final ahora = DateTime.now();
  await _probar('Actual', (c) => c.fetchClimaActual());
  // Hace 3 días: endpoint de pronóstico con start_date/end_date
  await _probar(
    'Histórico reciente',
    (c) => c.fetchClimaHistorico(
      fechaHora: ahora.subtract(const Duration(days: 3)),
    ),
  );
  // Hace 200 días: endpoint de archivo (archive-api)
  await _probar(
    'Histórico antiguo',
    (c) => c.fetchClimaHistorico(
      fechaHora: ahora.subtract(const Duration(days: 200)),
    ),
  );
}

// Un cliente por consulta: dispose() cierra el http.Client
Future<void> _probar(
  String nombre,
  Future<ClimaRawModels> Function(ClimaApiClient) consulta,
) async {
  final apiClient = ClimaApiClient();
  try {
    final clima = await consulta(apiClient);
    print('[$nombre] OK');
    print('  timestamp: ${clima.timestamp}');
    print('  temperature: ${clima.temperature}');
    print('  apparentTemperature: ${clima.apparentTermperature}');
    print('  relativeHumidity: ${clima.relativeHumidity}');
    print('  windSpeed: ${clima.windSpeed}');
    print('  weatherCode: ${clima.weatherCode}');
  } on ClimaApiException catch (e) {
    print('[$nombre] Error controlado: $e');
  } finally {
    apiClient.dispose();
  }
}
