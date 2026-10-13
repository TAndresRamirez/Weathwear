import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/storage/prenda_image_storage.dart';
import 'package:weathwear/domain/prendas/registrar_prenda_use_case.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';

// Fakes: el Interpreter real necesita canal de plataforma, no corre en flutter_test
class _FakeClassifier implements ClothingClassifier {
  final double confidence;
  _FakeClassifier(this.confidence);

  @override
  bool get isLoaded => true;
  @override
  Future<void> load() async {}
  @override
  Future<ClassificationResult> classify(String imagePath) async =>
      ClassificationResult(label: 'Polera', confidence: confidence);
  @override
  void dispose() {}
}

class _FakeStorage implements PrendaImageStorage {
  final List<String> deleted = [];
  @override
  Future<String> save(String sourcePath) async => '/saved/foto.jpg';
  @override
  Future<void> delete(String path) async => deleted.add(path);
}

class _FakeRepo extends PrendaRepository {
  final bool fail;
  PrendaModel? inserted;
  _FakeRepo({this.fail = false});

  @override
  Future<int> insert(PrendaModel prenda) async {
    if (fail) throw Exception('fallo de BD');
    inserted = prenda;
    return 1;
  }
}

void main() {
  RegistrarPrendaUseCase build({
    double confidence = 0.95,
    _FakeStorage? storage,
    _FakeRepo? repo,
  }) => RegistrarPrendaUseCase(
    _FakeClassifier(confidence),
    storage ?? _FakeStorage(),
    repo ?? _FakeRepo(),
  );

  test('analizar marca requiereConfirmacion si la confianza es baja', () async {
    final result = await build(confidence: 0.40).analizar('/tmp/x.jpg');
    expect(result.requiereConfirmacion, true);
  });

  test('registrar guarda la ruta persistente, no la temporal', () async {
    final repo = _FakeRepo();
    await build(repo: repo).registrar(
      sourcePath: '/cache/x.jpg',
      tipo: 'Polera',
      tempMin: 15,
      tempMax: 25,
      condicionAplicable: 'soleado',
    );
    expect(repo.inserted!.imagenRuta, '/saved/foto.jpg');
  });

  test('si el insert falla, se elimina la foto copiada', () async {
    final storage = _FakeStorage();
    final useCase = build(storage: storage, repo: _FakeRepo(fail: true));

    await expectLater(
      useCase.registrar(
        sourcePath: '/cache/x.jpg',
        tipo: 'Polera',
        tempMin: 15,
        tempMax: 25,
        condicionAplicable: 'soleado',
      ),
      throwsException,
    );
    expect(storage.deleted, ['/saved/foto.jpg']);
  });

  test('rango de temperatura invertido lanza PrendaRegistroException', () {
    expect(
      () => build().registrar(
        sourcePath: '/cache/x.jpg',
        tipo: 'Polera',
        tempMin: 15,
        tempMax: 25,
        condicionAplicable: 'soleado',
      ),
      throwsA(isA<PrendaRegistroException>()),
    );
  });
}
