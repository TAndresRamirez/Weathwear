import 'dart:math' as math;

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
    final entero = _mejor(clima, prendas, PrendaCategoria.entero);

    // El par superior+inferior compite como una unidad contra la prenda
    // entera: promedio de puntajes y peor distancia térmica de las dos.
    final par = superior != null && inferior != null
        ? (
            score: (superior.score + inferior.score) / 2,
            distancia: math.max(superior.distancia, inferior.distancia),
          )
        : null;

    if (par == null && entero == null) {
      throw const RecommendationException(
        'Se necesita una prenda entera, o una superior y una inferior',
      );
    }

    // Mismo criterio que _mejor: primero adecuación térmica, luego puntaje.
    // Ante empate gana el par (la comparación es estricta).
    final _Candidato? enteroElegido =
        entero != null &&
            (par == null ||
                _mejorQue(
                  entero.distancia,
                  entero.score,
                  par.distancia,
                  par.score,
                ))
        ? entero
        : null;

    // La capa exterior solo se incluye si realmente calza con el clima actual
    final exterior = _mejor(clima, prendas, PrendaCategoria.exterior);
    final capa = exterior != null && exterior.score >= umbralExterior
        ? exterior
        : null;

    if (enteroElegido != null) {
      return Outfit(
        entero: enteroElegido.prenda,
        exterior: capa?.prenda,
        similitud: _promedio([
          enteroElegido.score,
          if (capa != null) capa.score,
        ]),
      );
    }

    // Sin entero elegido, par != null está garantizado por el throw anterior
    final sup = superior!;
    final inf = inferior!;
    return Outfit(
      superior: sup.prenda,
      inferior: inf.prenda,
      exterior: capa?.prenda,
      similitud: _promedio([
        sup.score,
        inf.score,
        if (capa != null) capa.score,
      ]),
    );
  }

  // Puntaje total de una prenda para el clima dado
  double puntaje(ClimaModel clima, PrendaModel prenda) {
    final temp = puntajeTemperatura(
      clima.temperatura,
      prenda.tempMin,
      prenda.tempMax,
    );
    // La prenda puede servir para varias condiciones: basta que una coincida
    final cond = prenda.condiciones.contains(clima.condicion.toLowerCase())
        ? 1.0
        : 0.0;
    return pesoTemperatura * temp + pesoCondicion * cond;
  }

  // Afinidad de un conjunto de prendas con el clima: promedio de sus puntajes
  // (para las tarjetas de outfits guardados contra el clima de hoy)
  double afinidad(ClimaModel clima, Iterable<PrendaModel> prendas) {
    final lista = prendas.toList();
    if (lista.isEmpty) return 0;
    return lista.map((p) => puntaje(clima, p)).reduce((a, b) => a + b) /
        lista.length;
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

  bool _supera(_Candidato a, _Candidato b) =>
      _mejorQue(a.distancia, a.score, b.distancia, b.score);

  double _promedio(List<double> valores) =>
      valores.reduce((a, b) => a + b) / valores.length;

  // Menor distancia térmica primero; a igual distancia, mayor puntaje
  bool _mejorQue(double distA, double scoreA, double distB, double scoreB) =>
      distA != distB ? distA < distB : scoreA > scoreB;
}
