//temporal, validacion api Open-Meteo
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
    print('relativeHumidity: ${clima.relativeHumidity}');
    print('weatherCode: ${clima.weatherCode}');
  } on ClimaApiExeption catch (e) {
    print('Error controlado: ${e}');
  } finally {
    apiClient.dispose();
  }
}
