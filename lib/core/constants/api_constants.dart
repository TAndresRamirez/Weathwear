class ApiConstants {
  ApiConstants._();

  static const String baseUrl = "https://api.open-meteo.com/v1/forecast";

  //Coordenadas fijas en Santiago, chile
  //Despues pasara a geolocalizacion
  static const double defaultLatitude = -33.4489;
  static const double defaultLongitude = -70.6693;

  static const String timezone = "America/Santiago";
  static const Duration requestTimeout = Duration(seconds: 10);
}
