import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';

// Lo que necesita la UI : el outfit, el clima usado y si ese clima esta viejo
class RecomendacionResultado {
  final Outfit outfit;
  final ClimaModel clima;
  final bool climaDesactualizado;
  const RecomendacionResultado(
    this.outfit,
    this.clima,
    this.climaDesactualizado,
  );
}

// CU-03 ultimo clima + prendas activas -> engine -> persistencia
class GenerarRecomendacionUseCase {
  // Si el ETL falla (sin red, Android mata el background), el ultimo registro envejece
  static const Duration maxAntiguedad = Duration(hours: 3);

  final ClimaRepository _climaRepo;
  final PrendaRepository _prendaRepo;
  final RecomendacionRepository _recoRepo;
  final RecommendationEngine _engine;
  final DateTime Function() _now; // inyectable para testear la antiguedad

  GenerarRecomendacionUseCase(
    this._climaRepo,
    this._prendaRepo,
    this._recoRepo, {
    RecommendationEngine? engine,
    DateTime Function()? now,
  }) : _engine = engine ?? RecommendationEngine(),
       _now = now ?? DateTime.now;

  Future<RecomendacionResultado> call() async {
    final clima = await _climaRepo.getUltimo();
    if (clima == null) {
      throw const RecommendationException('Aun no hay datos climaticos');
    }

    final prendas = await _prendaRepo.getAll();
    final outfit = _engine.recommend(clima, prendas);

    // Idempotente: no duplica el historial si el outfit no cambio para este clima
    final previos = await _recoRepo.idsUltimoOutfit(clima.idClima!);
    final nuevos = outfit.prendas.map((p) => p.idPrenda!).toSet();
    final sinCambios =
        previos.length == nuevos.length && previos.containsAll(nuevos);
    if (!sinCambios) {
      await _recoRepo.insertOutfit(idClima: clima.idClima!, outfit: outfit);
    }

    final desactualizado = _now().difference(clima.fechaHora) > maxAntiguedad;
    return RecomendacionResultado(outfit, clima, desactualizado);
  }
}
