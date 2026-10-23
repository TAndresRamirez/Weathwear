import 'package:weathwear/core/constants/api_constants.dart';

class Coordenadas {
  final double latitud;
  final double longitud;
  const Coordenadas({required this.latitud, required this.longitud});

  /// Fallback cuando no hay ubicación del usuario
  static const santiago = Coordenadas(
    latitud: ApiConstants.defaultLatitude,
    longitud: ApiConstants.defaultLongitude,
  );

  Map<String, Object?> toJson() => {'lat': latitud, 'lon': longitud};

  factory Coordenadas.fromJson(Map<String, dynamic> json) => Coordenadas(
    latitud: (json['lat'] as num).toDouble(),
    longitud: (json['lon'] as num).toDouble(),
  );
}
