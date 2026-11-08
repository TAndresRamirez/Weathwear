import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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

  /// Clasifica varias franjas de una misma foto (RF-10: zona superior/inferior).
  /// Decodificar y recortar una foto de cámara (12 MP) puede tardar cerca de un segundo, así que se
  /// hace en otro isolate para no congelar la UI; la inferencia queda aquí
  /// porque el Interpreter no se puede enviar entre isolates.
  Future<List<ClassificationResult>> classifyZonas(
    String imagePath,
    List<ZonaVertical> zonas,
  ) async {
    if (!isLoaded) {
      throw const ClassifierException('Llama a load() antes de clasificar');
    }
    final tensores = await _prepararEnIsolate(imagePath, zonas);
    if (tensores == null) {
      throw ClassifierException(
        'Imagen invalida o formato no soportado: $imagePath',
      );
    }
    return [for (final t in tensores) _inferir(t)];
  }

  // Estático: así el closure de Isolate.run no captura `this` (el Interpreter)
  static Future<List<_Tensor>?> _prepararEnIsolate(
    String path,
    List<ZonaVertical> zonas,
  ) => Isolate.run(() => _prepararZonas(path, zonas));

  static List<_Tensor>? _prepararZonas(String path, List<ZonaVertical> zonas) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) return null;
    // El decoder no aplica la orientación EXIF: sin esto una foto vertical
    // llega acostada y "arriba/abajo" no corresponden al cuerpo.
    final orientada = img.bakeOrientation(decoded);
    // Se achica antes de recortar; el modelo igual trabaja a 224x224
    final base = orientada.height > 800
        ? img.copyResize(orientada, height: 800)
        : orientada;

    return [
      for (final z in zonas)
        _preprocess(
          img.copyCrop(
            base,
            x: 0,
            y: (z.desde * base.height).round(),
            width: base.width,
            height: ((z.hasta - z.desde) * base.height).round(),
          ),
        ),
    ];
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
