//Respuesta cruda del bloque "current" de Open-Meteo
//Sin transformar al esquema de la tabla Clima

class ClimaRawModels {
  final DateTime timestamp;
  final double temperature;
  final double relativeHumidity;
  final int weatherCode;
  final double? apparentTermperature; // °C
  final double? windSpeed; // km/h

  const ClimaRawModels({
    required this.timestamp,
    required this.temperature,
    required this.relativeHumidity,
    required this.weatherCode,
    this.apparentTermperature,
    this.windSpeed,
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
      apparentTermperature: (current['apparent_temperature'] as num?)
          ?.toDouble(),
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble(),
    );
  }
}
