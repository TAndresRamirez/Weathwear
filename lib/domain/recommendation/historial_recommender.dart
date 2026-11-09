import 'dart:math' as math;

import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/models/uso_historial.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

/// Conjunto candidato que sale del historial, con lo necesario para mostrarlo,
/// justificarlo y registrar su uso.
class CandidatoHistorial {
  final int idOutfit;
  final Outfit outfit;

  /// Suma de las similitudes de sus usos seleccionados (criterio de orden)
  final double puntaje;

  /// Cuántos de los k usos más similares corresponden a este conjunto
  final int usosSimilares;
  final DateTime ultimoUso;

  const CandidatoHistorial({
    required this.idOutfit,
    required this.outfit,
    required this.puntaje,
    required this.usosSimilares,
    required this.ultimoUso,
  });

  String get justificacion =>
      'Utilizaste este conjunto $usosSimilares '
      '${usosSimilares == 1 ? 'vez' : 'veces'} con un clima similar';
}

/// Motor por historial (CU-03, RF-05, Tabla 13 del informe): recomienda el
/// conjunto que el usuario usó con un clima parecido al actual.
/// Función pura como RecommendationEngine: no toca BD ni red.
class HistorialRecommender {
  // Parámetros de la Tabla 13
  static const double pesoTemperatura = 0.60;
  static const double pesoCondicion = 0.25;
  static const double pesoHumedad = 0.15;
  static const double rangoTemperatura = 30.0; // °C de diferencia = distancia máxima
  static const double umbralSimilitud = 0.75;
  static const int k = 5;

  // Tolerancia para comparar dobles (0.75 calculado puede quedar en 0.7499...)
  static const double _epsilon = 1e-9;

  /// s = 1 − d, con d = wT·min(1, |ΔT|/30) + wH·|ΔH|/100 + wC·δC
  double similitud(ClimaModel actual, UsoHistorial uso) {
    final dT = math.min(
      1.0,
      (actual.temperatura - uso.temperatura).abs() / rangoTemperatura,
    );
    final dH = math.min(1.0, (actual.humedad - uso.humedad).abs() / 100);
    final dC = _normalizar(actual.condicion) == _normalizar(uso.condicion)
        ? 0.0
        : 1.0;
    return 1 - (pesoTemperatura * dT + pesoHumedad * dH + pesoCondicion * dC);
  }

  /// Candidatos ordenados del mejor al peor; vacío si ningún uso supera el
  /// umbral (entonces el caso de uso aplica el respaldo por rango).
  List<CandidatoHistorial> recomendar(
    ClimaModel actual,
    List<UsoHistorial> usos,
  ) {
    // 1. Similitud de cada uso y filtro por umbral
    final similares = [
      for (final u in usos)
        (uso: u, s: similitud(actual, u)),
    ].where((e) => e.s >= umbralSimilitud - _epsilon).toList()
      // 2. Los k más similares; a igual similitud, el más reciente
      ..sort((a, b) {
        final porS = _comparar(b.s, a.s);
        return porS != 0 ? porS : b.uso.fechaUso.compareTo(a.uso.fechaUso);
      });
    final seleccion = similares.take(k);

    // 3. Agrupar por conjunto: puntaje = suma de similitudes
    final grupos = <int, _Grupo>{};
    for (final e in seleccion) {
      grupos.putIfAbsent(e.uso.idOutfit, () => _Grupo(e.uso)).sumar(e);
    }

    // 4. Mayor puntaje primero; empate -> uso más reciente
    final ordenados = grupos.values.toList()
      ..sort((a, b) {
        final porPuntaje = _comparar(b.puntaje, a.puntaje);
        return porPuntaje != 0
            ? porPuntaje
            : b.ultimoUso.compareTo(a.ultimoUso);
      });

    return [
      for (final g in ordenados)
        CandidatoHistorial(
          idOutfit: g.base.idOutfit,
          outfit: outfitDesde(g.base.prendas, similitud: g.promedio),
          puntaje: g.puntaje,
          usosSimilares: g.cantidad,
          ultimoUso: g.ultimoUso,
        ),
    ];
  }

  /// Arma el Outfit del motor a partir de las prendas de un outfit guardado
  /// (composición ya validada por el repositorio).
  static Outfit outfitDesde(
    List<PrendaModel> prendas, {
    required double similitud,
  }) {
    PrendaModel? de(PrendaCategoria c) =>
        prendas.where((p) => p.categoria == c).firstOrNull;
    return Outfit(
      superior: de(PrendaCategoria.superior),
      inferior: de(PrendaCategoria.inferior),
      entero: de(PrendaCategoria.entero),
      exterior: de(PrendaCategoria.exterior),
      similitud: similitud,
    );
  }

  static String _normalizar(String condicion) => condicion.trim().toLowerCase();

  // Compara con tolerancia: diferencias < epsilon cuentan como empate
  static int _comparar(double a, double b) =>
      (a - b).abs() < _epsilon ? 0 : a.compareTo(b);
}

class _Grupo {
  _Grupo(this.base) : ultimoUso = base.fechaUso;

  final UsoHistorial base;
  double puntaje = 0;
  int cantidad = 0;
  DateTime ultimoUso;

  void sumar(({UsoHistorial uso, double s}) e) {
    puntaje += e.s;
    cantidad++;
    if (e.uso.fechaUso.isAfter(ultimoUso)) ultimoUso = e.uso.fechaUso;
  }

  double get promedio => cantidad == 0 ? 0 : puntaje / cantidad;
}
