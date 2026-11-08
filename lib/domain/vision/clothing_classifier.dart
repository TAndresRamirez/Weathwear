import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:weathwear/domain/vision/color_histograma.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  const ClassificationResult({required this.label, required this.confidence});

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)})';
}

/// Franja horizontal de la foto, en fracciones de la altura (0 = borde superior).
typedef ZonaVertical = ({double desde, double hasta});

// Tensor de entrada [1, 224, 224, 3]
typedef _Tensor = List<List<List<List<double>>>>;

// Lo que vuelve del isolate por cada zona
typedef _ZonaPreparada = ({_Tensor tensor, List<double> hist});

/// Resultado de una zona: tipo según el modelo + histograma de color de esa
/// franja (para elegir cuál prenda de ese tipo es, ver ColorHistograma).
class ZonaClasificada {
  final ClassificationResult resultado;
  final List<double> histograma;
  const ZonaClasificada(this.resultado, this.histograma);
}

class ClassifierException implements Exception {
  final String message;
  const ClassifierException(this.message);
  @override
  String toString() => 'ClasifierExeption: $message';
}

// Clasificador de prendas basado en modelo TFLite (floating point)
// Exportado desde Teachable Machine
// Input: [1, 224, 224, 3] float32, normalizado a [-1,1]
// Output: [1,N] float32 con probabilidades por clase (sofmax)

class ClothingClassifier {
  static const int _inputSize = 224;
  static const String _modelAsset = 'assets/models/clothing_model.tflite';
  static const String _labelsAsset = 'assets/models/labels.txt';

  Interpreter? _interpreter;
  List<String> _labels = const [];

  bool get isLoaded => _interpreter != null;

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      final raw = await rootBundle.loadString(_labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .map((l) => l.replaceFirst(RegExp(r'^\d+\s+'), ''))
          .toList();
    } catch (e) {
      throw ClassifierException(
        'No se pudo cargar el modelo o las etiquetas: $e',
      );
    }
  }

  Future<ClassificationResult> classify(String imagePath) async {
    if (!isLoaded) {
      throw const ClassifierException('Llama a load() antes de clasificar');
    }

    final file = File(imagePath);
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw ClassifierException(
        'Imagen invalida o formato no soportado: $imagePath',
      );
    }

    return _inferir(_preprocess(decoded));
  }

  /// Clasifica varias franjas de una misma foto (RF-10: zona superior/inferior)
  /// y calcula su histograma de color, aprovechando la misma decodificación.
  /// Decodificar y recortar una foto de cámara (12 MP) puede tardar cerca de
  /// un segundo, así que se hace en otro isolate para no congelar la UI; la
  /// inferencia queda aquí porque el Interpreter no se puede enviar entre
  /// isolates.
  Future<List<ZonaClasificada>> classifyZonas(
    String imagePath,
    List<ZonaVertical> zonas,
  ) async {
    if (!isLoaded) {
      throw const ClassifierException('Llama a load() antes de clasificar');
    }
    final preparadas = await _prepararEnIsolate(imagePath, zonas);
    if (preparadas == null) {
      throw ClassifierException(
        'Imagen invalida o formato no soportado: $imagePath',
      );
    }
    return [
      for (final z in preparadas) ZonaClasificada(_inferir(z.tensor), z.hist),
    ];
  }

  // Estático: así el closure de Isolate.run no captura `this` (el Interpreter)
  static Future<List<_ZonaPreparada>?> _prepararEnIsolate(
    String path,
    List<ZonaVertical> zonas,
  ) => Isolate.run(() => _prepararZonas(path, zonas));

  static List<_ZonaPreparada>? _prepararZonas(
    String path,
    List<ZonaVertical> zonas,
  ) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) return null;
    // El decoder no aplica la orientación EXIF: sin esto una foto vertical
    // llega acostada y "arriba/abajo" no corresponden al cuerpo.
    final orientada = img.bakeOrientation(decoded);
    // Se achica antes de recortar; el modelo igual trabaja a 224x224
    final base = orientada.height > 800
        ? img.copyResize(orientada, height: 800)
        : orientada;

    final resultado = <_ZonaPreparada>[];
    for (final z in zonas) {
      final recorte = img.copyCrop(
        base,
        x: 0,
        y: (z.desde * base.height).round(),
        width: base.width,
        height: ((z.hasta - z.desde) * base.height).round(),
      );
      resultado.add((
        tensor: _preprocess(recorte),
        // Color solo del centro: la persona suele ir al medio y los costados
        // son fondo
        hist: ColorHistograma.deImagen(recorte, margenX: 0.3, margenY: 0.1),
      ));
    }
    return resultado;
  }

  ClassificationResult _inferir(_Tensor input) {
    final output = [List<double>.filled(_labels.length, 0.0)];
    _interpreter!.run(input, output);

    final probs = output[0];
    var bestIndex = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[bestIndex]) bestIndex = i;
    }

    return ClassificationResult(
      label: _labels[bestIndex],
      confidence: probs[bestIndex],
    );
  }

  // Redimension a 224x224 y normaliza cada canal a [-1,1]
  static _Tensor _preprocess(img.Image image) {
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
    );

    return [
      List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [(p.r / 127.5) - 1, (p.g / 127.5) - 1, (p.b / 127.5) - 1];
        });
      }),
    ];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
