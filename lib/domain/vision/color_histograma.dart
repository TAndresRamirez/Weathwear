import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// Histograma de color en HSV para elegir CUÁL prenda de un tipo aparece en la
// foto (RF-10). El clasificador solo sabe el tipo ("Polera"); el color
// distingue entre tus poleras. Sin dependencias nuevas: solo el paquete image.
//
// - 12 tonos x 3 saturaciones x 3 brillos para colores
// - 4 bins de "gris" (negro, gris oscuro, gris claro, blanco) para píxeles con
//   poca saturación o muy oscuros, donde el tono no significa nada
// Similitud = intersección de histogramas normalizados: 1 = mismo reparto de
// colores, 0 = ninguno en común. Ignora la forma y el estampado.
class ColorHistograma {
  ColorHistograma._();

  static const int _binsH = 12;
  static const int _binsS = 3;
  static const int _binsV = 3;
  static const int _binsGris = 4;
  static const int longitud = _binsH * _binsS * _binsV + _binsGris;

  // Bajo estos umbrales el píxel se cuenta como gris/negro
  static const double _satMin = 0.20;
  static const double _valMin = 0.15;

  // ~4000 píxeles muestreados bastan para un histograma estable
  static const int _muestras = 4000;

  // Caché en memoria por ruta: las fotos de prendas no cambian una vez guardadas
  static final Map<String, List<double>> _cache = {};

  /// Histograma del centro de [imagen]: [margenX]/[margenY] recortan los bordes
  /// (fondo) en cada lado, como fracción del ancho/alto.
  static List<double> deImagen(
    img.Image imagen, {
    double margenX = 0.2,
    double margenY = 0.2,
  }) {
    final x0 = (imagen.width * margenX).floor();
    final x1 = (imagen.width * (1 - margenX)).ceil();
    final y0 = (imagen.height * margenY).floor();
    final y1 = (imagen.height * (1 - margenY)).ceil();
    final area = math.max(1, (x1 - x0) * (y1 - y0));
    final paso = math.max(1, math.sqrt(area / _muestras).floor());

    final hist = List<double>.filled(longitud, 0);
    var total = 0;
    for (var y = y0; y < y1; y += paso) {
      for (var x = x0; x < x1; x += paso) {
        final p = imagen.getPixel(x, y);
        hist[_bin(
          p.rNormalized.toDouble(),
          p.gNormalized.toDouble(),
          p.bNormalized.toDouble(),
        )]++;
        total++;
      }
    }
    if (total == 0) return hist;
    return [for (final v in hist) v / total];
  }

  /// Intersección de histogramas, en [0, 1]. 0 si alguno no es válido.
  static double similitud(List<double> a, List<double> b) {
    if (a.length != longitud || b.length != longitud) return 0;
    var suma = 0.0;
    for (var i = 0; i < longitud; i++) {
      suma += math.min(a[i], b[i]);
    }
    return suma;
  }

  /// Histogramas de varias fotos de prendas, calculados en otro isolate y
  /// cacheados. Las fotos ilegibles se omiten del resultado.
  static Future<Map<String, List<double>>> deArchivos(
    Iterable<String> paths,
  ) async {
    final faltantes = paths.where((p) => !_cache.containsKey(p)).toSet();
    if (faltantes.isNotEmpty) {
      final nuevos = await _calcularEnIsolate(faltantes.toList());
      _cache.addAll(nuevos);
    }
    return {
      for (final p in paths)
        if (_cache[p] != null) p: _cache[p]!,
    };
  }

  // Estático y con argumentos simples: el closure no captura estado del caller
  static Future<Map<String, List<double>>> _calcularEnIsolate(
    List<String> paths,
  ) => Isolate.run(() {
    final resultado = <String, List<double>>{};
    for (final path in paths) {
      final h = _deArchivo(path);
      if (h != null) resultado[path] = h;
    }
    return resultado;
  });

  static List<double>? _deArchivo(String path) {
    try {
      final decoded = img.decodeImage(File(path).readAsBytesSync());
      if (decoded == null) return null;
      final orientada = img.bakeOrientation(decoded);
      // Para el color no hace falta resolución
      final chica = orientada.width > 256
          ? img.copyResize(orientada, width: 256)
          : orientada;
      return deImagen(chica);
    } catch (_) {
      return null; // foto borrada o corrupta: esa prenda queda sin color
    }
  }

  static int _bin(double r, double g, double b) {
    final mx = math.max(r, math.max(g, b));
    final mn = math.min(r, math.min(g, b));
    final v = mx;
    final s = mx == 0 ? 0.0 : (mx - mn) / mx;

    if (s < _satMin || v < _valMin) {
      final i = (v * _binsGris).floor();
      return _binsH * _binsS * _binsV + math.min(i, _binsGris - 1);
    }

    // Tono en [0, 1)
    final d = mx - mn;
    double h;
    if (mx == r) {
      h = ((g - b) / d) % 6;
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h = (h / 6) % 1;

    final hb = math.min((h * _binsH).floor(), _binsH - 1);
    final sb = math.min(
      ((s - _satMin) / (1 - _satMin) * _binsS).floor(),
      _binsS - 1,
    );
    final vb = math.min(
      ((v - _valMin) / (1 - _valMin) * _binsV).floor(),
      _binsV - 1,
    );
    return hb * _binsS * _binsV + sb * _binsV + vb;
  }
}
