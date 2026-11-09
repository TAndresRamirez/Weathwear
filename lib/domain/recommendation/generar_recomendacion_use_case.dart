import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/domain/recommendation/historial_recommender.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';

// Lo que necesita la UI: el outfit, el clima usado, si ese clima está viejo y,
// cuando sale del historial, el candidato (justificación, id) y la alternativa
class RecomendacionResultado {
  final Outfit outfit;
  final ClimaModel clima;
  final bool climaDesactualizado;

  /// null: se aplicó el respaldo por rango de temperatura
  final CandidatoHistorial? historial;

  /// Segundo conjunto del historial, si existe
  final CandidatoHistorial? alternativa;

  const RecomendacionResultado(
    this.outfit,
    this.clima,
    this.climaDesactualizado, {
    this.historial,
    this.alternativa,
  });

  bool get desdeHistorial => historial != null;

  String get justificacion =>
      historial?.justificacion ??
      'Según el rango de temperatura de tus prendas '
          '(aún no hay usos con un clima similar)';
}

// CU-03: último clima -> historial de usos (similitud >= umbral) -> outfit.
// Si el historial no alcanza (primeros días), respaldo por rango de
// temperatura con RecommendationEngine. Luego se persiste en Recomendacion.
class GenerarRecomendacionUseCase {
  // Si el ETL falla (sin red, Android mata el background), el ultimo registro envejece
  static const Duration maxAntiguedad = Duration(hours: 3);

  final ClimaRepository _climaRepo;
  final PrendaRepository _prendaRepo;
  final RecomendacionRepository _recoRepo;
  final OutfitRepository _outfitRepo;
  final RecommendationEngine _engine;
  final HistorialRecommender _historial;
  final DateTime Function() _now; // inyectable para testear la antiguedad

  GenerarRecomendacionUseCase(
    this._climaRepo,
    this._prendaRepo,
    this._recoRepo, {
    OutfitRepository? outfitRepo,
    RecommendationEngine? engine,
    HistorialRecommender? historial,
    DateTime Function()? now,
  }) : _outfitRepo = outfitRepo ?? OutfitRepository(),
       _engine = engine ?? RecommendationEngine(),
       _historial = historial ?? HistorialRecommender(),
       _now = now ?? DateTime.now;

  Future<RecomendacionResultado> call() async {
    final clima = await _climaRepo.getUltimo();
    if (clima == null) {
      throw const RecommendationException('Aun no hay datos climaticos');
    }

    final candidatos = _historial.recomendar(
      clima,
      await _outfitRepo.usosConClima(),
    );
    final mejor = candidatos.firstOrNull;
    // Respaldo: solo se cargan las prendas si el historial no alcanzó
    final outfit =
        mejor?.outfit ?? _engine.recommend(clima, await _prendaRepo.getAll());

    // Idempotente: no duplica el historial si el outfit no cambio para este clima
    final previos = await _recoRepo.idsUltimoOutfit(clima.idClima!);
    final nuevos = outfit.prendas.map((p) => p.idPrenda!).toSet();
    final sinCambios =
        previos.length == nuevos.length && previos.containsAll(nuevos);
    if (!sinCambios) {
      await _recoRepo.insertOutfit(idClima: clima.idClima!, outfit: outfit);
    }

    final desactualizado = _now().difference(clima.fechaHora) > maxAntiguedad;
    return RecomendacionResultado(
      outfit,
      clima,
      desactualizado,
      historial: mejor,
      alternativa: candidatos.length > 1 ? candidatos[1] : null,
    );
  }
}
