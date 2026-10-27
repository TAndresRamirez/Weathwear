import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

class OutfitException implements Exception {
  final String message;
  const OutfitException(this.message);
  @override
  String toString() => 'OutfitException: $message';
}

/// Guarda un outfit (desde una recomendación o creado a mano).
/// Valida la composición y evita duplicados; los mensajes son para la UI.
class GuardarOutfitUseCase {
  GuardarOutfitUseCase(this._repo);
  final OutfitRepository _repo;

  Future<int> call(
    List<PrendaModel> prendas, {
    String origen = OutfitOrigen.manual,
  }) async {
    final ids = <int>{};
    for (final p in prendas) {
      final id = p.idPrenda;
      if (id == null) {
        throw const OutfitException('Hay una prenda que aún no está guardada');
      }
      ids.add(id);
    }
    if (ids.length != prendas.length) {
      throw const OutfitException('Hay prendas repetidas en el outfit');
    }

    int cuantas(PrendaCategoria c) =>
        prendas.where((p) => p.categoria == c).length;
    if (cuantas(PrendaCategoria.superior) != 1 ||
        cuantas(PrendaCategoria.inferior) != 1 ||
        cuantas(PrendaCategoria.exterior) > 1) {
      throw const OutfitException(
        'Un outfit lleva una prenda superior, una inferior y, '
        'opcionalmente, una exterior',
      );
    }

    if (await _repo.buscarIdPorPrendas(ids) != null) {
      throw const OutfitException('Este outfit ya está guardado');
    }
    return _repo.insert(idsPrenda: ids.toList(), origen: origen);
  }
}
