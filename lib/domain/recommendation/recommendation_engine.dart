import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

class RecommendationException implements Exception {
  final String message;
  const RecommendationException(this.message);
  @override
  String toString() => 'RecomendationException: $message';
}

// distancio = grados fuera del rango de la prenda (0 si la temperatura esta dentro)
typedef _Candidato = ({PrendaModel prenda, double score, double distancia});

// Motor de similitud (CU-03, RF-05). Funcion pura: no accede a BD ni a red,
// recibe el clima y las prendas ya cargadas, asi se testea sin mocks
class RecommendationEngine {
  static const double pesoTemperatura = 0.7;
  static const double pesoCondicion = 0.3;

  // Grados fuera del rango a los que el puntaje de temperatura llega a 0
  static const double toleranciaGrados = 8.0;

  // Puntaje minimo para que la capa exterior entre al outfit
  static const double umbralExterior = 0.5;

  Outfit recommend(ClimaModel clima, List<PrendaModel> prendas) {
    final superior = _mejor(clima, prendas, PrendaCategoria.superior);
    final inferior = _mejor(clima, prendas, PrendaCategoria.inferior);

    if (superior == null || inferior == null) {
      throw const RecommendationException(
        'Se necesita al menos una prenda superior y una inferior',
      );
    }

    // La capa exterior solo se incluye si realmente calza con el clima actual
    final exterior = _mejor(clima, prendas, PrendaCategoria.exterior);
    final incluirExterior =
        exterior != null && exterior.score >= umbralExterior;

    final scores = [
      superior.score,
      inferior.score,
      if (incluirExterior) exterior.score,
    ];

    return Outfit(
      superior: superior.prenda,
      inferior: inferior.prenda,
      exterior: incluirExterior ? exterior.prenda : null,
      similitud: scores.reduce((a, b) => a + b) / scores.length,
    );
  }

  // Puntaje total de una prenda para el clima dado
  double puntaje(ClimaModel clima, PrendaModel prenda) {
    final temp = puntajeTemperatura(
      clima.temperatura,
      prenda.tempMin,
      prenda.tempMax,
    );
    final cond =
        prenda.condicionAplicable.trim().toLowerCase() ==
            clima.condicion.toLowerCase()
        ? 1.0
        : 0.0;
    return pesoTemperatura * temp + pesoCondicion * cond;
  }

  // Dentro del rango: 0.75-1.0 (mas alto cuanto mas cerca del centro).
  // Fuera del rango: cae linealmente desde 0.75 hasta 0.
  // Es continua en los bordes del rango, sin saltos bruscos.
  double puntajeTemperatura(double temp, double min, double max) {
    if (temp >= min && temp <= max) {
      final mitad = (max - min) / 2;
      final distNorm = mitad == 0
          ? 0.0
          : (temp - (min + max) / 2).abs() / mitad;
      return 1 - 0.25 * distNorm;
    }
    final fuera = temp < min ? min - temp : temp - max;
    return (0.75 * (1 - fuera / toleranciaGrados)).clamp(0.0, 0.75).toDouble();
  }

  // Mejor prenda de una categoria; ante empate gana la primera encontrada
  _Candidato? _mejor(
    ClimaModel clima,
    List<PrendaModel> prendas,
    PrendaCategoria categoria,
  ) {
    final t = clima.temperatura;
    _Candidato? mejor;
    for (final p in prendas) {
      if (PrendaCategoriaMapper.fromTipo(p.tipo) != categoria) continue;
      final distancia = t < p.tempMin
          ? p.tempMin - t
          : (t > p.tempMax ? t - p.tempMax : 0.0);
      final candidato = (
        prenda: p,
        score: puntaje(clima, p),
        distancia: distancia,
      );
      if (mejor == null || _supera(candidato, mejor)) mejor = candidato;
    }
    return mejor;
  }

  bool _supera(_Candidato a, _Candidato b) => a.distancia != b.distancia
      ? a.distancia < b.distancia
      : a.score > b.score;
}
