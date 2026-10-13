import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/storage/prenda_image_storage.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';

class PrendaRegistroException implements Exception {
  final String message;
  const PrendaRegistroException(this.message);
  @override
  String toString() => 'PrendaRegistroException: $message';
}

// Resultado del paso 1: sugerencia del modelo, aun sin persistir nada
class PrendaAnalisis {
  final ClassificationResult clasificacion;
  final bool requiereConfirmacion;
  const PrendaAnalisis(this.clasificacion, this.requiereConfirmacion);
}

// CU-02 + CU-05: foto -> clasificacion -> guardado
// Se divide en dos pasos para poder confirmar o corregir el tipo antes de persistir
// 1.analizar(): clasifica, no guarda nada
// 2.registrar(): copia la foto y la inserta en la BD
class RegistrarPrendaUseCase {
  static const double umbralConfianza = 0.70;

  final ClothingClassifier _classifier;
  final PrendaImageStorage _storage;
  final PrendaRepository _repository;

  RegistrarPrendaUseCase(this._classifier, this._storage, this._repository);

  Future<PrendaAnalisis> analizar(String imagePath) async {
    // Carga perezosa: el Interpreter es costoso, se instancia una sola vez
    if (!_classifier.isLoaded) await _classifier.load();

    final result = await _classifier.classify(imagePath);
    return PrendaAnalisis(result, result.confidence < umbralConfianza);
  }

  // [tipo] viene de la sugerencia del modelo o de la correccion manual
  // Retorna el id_prenda insertado
  Future<int> registrar({
    required String sourcePath,
    required String tipo,
    required double tempMin,
    required double tempMax,
    required String condicionAplicable,
  }) async {
    // Validar antes de tocar disco o BD, con mensaje legible para UI
    if (tempMin > tempMax) {
      throw const PrendaRegistroException(
        'La temperatura minima no puede superar la maxima',
      );
    }
    if (condicionAplicable.trim().isEmpty) {
      throw const PrendaRegistroException('Falta la condicion climatica');
    }
    PrendaCategoriaMapper.fromTipo(tipo); //ArgumentError si el tipo no existe

    final savedPath = await _storage.save(sourcePath);
    try {
      return await _repository.insert(
        PrendaModel(
          tipo: tipo,
          imagenRuta: savedPath,
          tempMin: tempMin,
          tempMax: tempMax,
          condicionAplicable: condicionAplicable.trim(),
        ),
      );
    } catch (_) {
      // Sin esto quedaria una foto huerfana en disco sin fila en la BD
      await _storage.delete(savedPath);
      rethrow;
    }
  }
}
