import 'dart:io';

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

    final input = _preprocess(decoded);
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
  List<List<List<List<double>>>> _preprocess(img.Image image) {
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
    );

    return [
      List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [(p.r / 127.5) - 1, (p.g / 127.5) - 1, (p.g / 127.5) - 1];
        });
      }),
    ];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
