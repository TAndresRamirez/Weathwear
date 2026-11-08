class ApiConstants {
  ApiConstants._();

  static const String baseUrl = "https://api.open-meteo.com/v1/forecast";

  // Reanálisis histórico (ERA5). Se usa para fechas más antiguas que
  // [diasPasadosForecast]; tiene unos días de retraso respecto a hoy.
  static const String archiveUrl =
      "https://archive-api.open-meteo.com/v1/archive";

  // El endpoint de pronóstico acepta start_date/end_date hasta ~92 días
  // hacia atrás; se deja margen.
  static const int diasPasadosForecast = 90;

  //Coordenadas fijas en Santiago, chile
  //Despues pasara a geolocalizacion
  static const double defaultLatitude = -33.4489;
  static const double defaultLongitude = -70.6693;

  static const String timezone = "America/Santiago";
  static const Duration requestTimeout = Duration(seconds: 10);

  // Variables del bloque "current" que se piden a Open-Meteo
  static const String currentParams =
      'temperature_2m,relative_humidity_2m,weather_code,'
      'apparent_temperature,wind_speed_10m';

  // Mismas variables en resolución horaria (clima de una foto, RF-11)
  static const String hourlyParams = currentParams;
}
