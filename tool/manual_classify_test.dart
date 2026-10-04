// Prueba manual del classificador contra una imagen real de la galeria
// Uso: flutter run -t tool/manual_classify_test.dart -d device_id

import 'package:flutter/material.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const ManualClassifyTestApp());

class ManualClassifyTestApp extends StatelessWidget {
  const ManualClassifyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ClassifyTestScreen());
  }
}

class ClassifyTestScreen extends StatefulWidget {
  const ClassifyTestScreen({super.key});

  @override
  State<ClassifyTestScreen> createState() => _ClassifyTestScreenState();
}

class _ClassifyTestScreenState extends State<ClassifyTestScreen> {
  final _classifier = ClothingClassifier();
  final _picker = ImagePicker();
  String _resultText = 'Sin resultado aun';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _classifier.load();
  }

  Future<void> _pickAndClassify() async {
    final photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo == null) return;

    setState(() => _loading = true);
    try {
      final result = await _classifier.classify(photo.path);
      setState(() => _resultText = result.toString());
    } catch (e) {
      setState(() => _resultText = 'Error> $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test classificador')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_resultText, style: const TextStyle(fontSize: 100)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _pickAndClassify,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Elegir foto'),
            ),
          ],
        ),
      ),
    );
  }
}
