import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';

/// "Usar hoy": registra el uso con el último clima conocido.
class UsarOutfitUseCase {
  UsarOutfitUseCase(
    this._outfitRepo,
    this._climaRepo, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final OutfitRepository _outfitRepo;
  final ClimaRepository _climaRepo;
  final DateTime Function() _now; // inyectable para testear "un uso por día"

  /// true si se registró; false si hoy ya estaba registrado.
  Future<bool> call(int idOutfit) async {
    final idClima = (await _climaRepo.getUltimo())?.idClima;
    if (idClima == null) {
      throw const OutfitException('Aún no hay datos climáticos');
    }
    return _outfitRepo.registrarUso(
      idOutfit: idOutfit,
      idClima: idClima,
      fecha: _now(),
    );
  }
}
