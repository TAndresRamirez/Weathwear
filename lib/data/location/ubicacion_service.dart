import 'package:geolocator/geolocator.dart';
import 'package:weathwear/data/models/coordenadas.dart';
import 'package:weathwear/data/storage/ubicacion_storage.dart';

class UbicacionException implements Exception {
  final String message;
  const UbicacionException(this.message);
  @override
  String toString() => 'UbicacionException: $message';
}

class UbicacionService {
  final UbicacionStorage _storage;
  UbicacionService({UbicacionStorage? storage})
    : _storage = storage ?? UbicacionStorage();

  /// Solo primer plano: pide permiso si hace falta, lee el GPS y lo cachea.
  Future<Coordenadas> actualizar() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UbicacionException('El GPS está desactivado');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw const UbicacionException('Permiso de ubicación denegado');
    }

    try {
      // Precisión baja (red/celdas): basta para clima y gasta menos batería
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final coords = Coordenadas(
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
      await _storage.guardar(coords);
      return coords;
    } catch (e) {
      throw UbicacionException('No se pudo obtener la ubicación: $e');
    }
  }

  /// Seguro en segundo plano: solo lee lo cacheado, nunca toca el GPS.
  Future<Coordenadas> ultimaConocida() async =>
      await _storage.leer() ?? Coordenadas.santiago;

  /// Intenta ubicación fresca; si falla, cae a la última conocida.
  Future<Coordenadas> obtener() async {
    try {
      return await actualizar();
    } on UbicacionException {
      return ultimaConocida();
    }
  }
}
