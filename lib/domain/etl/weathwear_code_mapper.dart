// Mapeo de codigo WMO de Open-Meteo a categorias usadas en el proyecto

class WeathwearCodeMapper {
  static String toCondicion(int weatherCode) {
    if (weatherCode == 0) return 'soleado';
    if (weatherCode <= 3) return 'parcialmente nublado';
    if (weatherCode <= 48) return 'nublado';
    if (weatherCode <= 67) return 'llovizna';
    if (weatherCode <= 77) return 'nieve';
    if (weatherCode <= 82) return 'lluvia';
    if (weatherCode <= 99) return 'tormenta';
    throw ArgumentError('weatherCode fuera de rango WMO: $weatherCode');
  }
}
