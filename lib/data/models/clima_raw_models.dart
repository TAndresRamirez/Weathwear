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

  /// Bloque "hourly" (clima histórico, RF-11): toma la hora más cercana a
  /// [objetivo]. Las horas sin datos (null) se saltan; si ninguna sirve,
  /// FormatException, que el cliente convierte en ClimaApiParseException.
  factory ClimaRawModels.fromHourlyJson(
    Map<String, dynamic> json,
    DateTime objetivo,
  ) {
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) {
      throw const FormatException('Respuesta sin bloque "hourly"');
    }
    final tiempos = (hourly['time'] as List?) ?? const [];
    List<dynamic> serie(String clave) => (hourly[clave] as List?) ?? const [];
    final temps = serie('temperature_2m');
    final humedades = serie('relative_humidity_2m');
    final codigos = serie('weather_code');
    final sensaciones = serie('apparent_temperature');
    final vientos = serie('wind_speed_10m');

    // null si el índice no existe o el valor viene null
    num? valor(List<dynamic> lista, int i) =>
        i < lista.length ? lista[i] as num? : null;

    int? mejor;
    Duration? menorDiferencia;
    for (var i = 0; i < tiempos.length; i++) {
      if (valor(temps, i) == null ||
          valor(humedades, i) == null ||
          valor(codigos, i) == null) {
        continue;
      }
      final diferencia = DateTime.parse(tiempos[i] as String)
          .difference(objetivo)
          .abs();
      if (menorDiferencia == null || diferencia < menorDiferencia) {
        mejor = i;
        menorDiferencia = diferencia;
      }
    }
    if (mejor == null) {
      throw const FormatException('Sin datos horarios para esa fecha');
    }

    return ClimaRawModels(
      timestamp: DateTime.parse(tiempos[mejor] as String),
      temperature: valor(temps, mejor)!.toDouble(),
      relativeHumidity: valor(humedades, mejor)!.toDouble(),
      weatherCode: valor(codigos, mejor)!.toInt(),
      apparentTermperature: valor(sensaciones, mejor)?.toDouble(),
      windSpeed: valor(vientos, mejor)?.toDouble(),
    );
  }
}
