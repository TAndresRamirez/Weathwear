//Respuesta cruda del bloque "current" de Open-Meteo
//Sin transformar al esquema de la tabla Clima

class ClimaRawModels {
  final DateTime timestamp;
  final double temperature;
  final double relativeHumidity;
  final int weatherCode;

  const ClimaRawModels({
    required this.timestamp,
    required this.temperature,
    required this.relativeHumidity,
    required this.weatherCode,
  });

  factory ClimaRawModels.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) {
      throw const FormatException('Respuesta sin bloque "current"');
    }
    return ClimaRawModels(
      timestamp: DateTime.parse(current['time'] as String),
      temperature: (current['temperature_2m'] as num).toDouble(),
      relativeHumidity: (current['relative_humidity_2m'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
    );
  }
}
