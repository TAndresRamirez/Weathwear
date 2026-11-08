import 'dart:math' as math;

import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

class OutfitOrigen {
  OutfitOrigen._();
  static const String recomendacion = 'recomendacion';
  static const String manual = 'manual';
  static const String foto =
      'foto'; // creado al registrar un uso desde foto (RF-10)
}

/// Outfit persistido (no confundir con `Outfit`, el resultado del motor).
/// [prendas] viene ordenada: superior, inferior, entero y exterior (si existen).
class OutfitGuardado {
  final int idOutfit;
  final DateTime fechaCreacion;
  final String origen;
  final List<PrendaModel> prendas;

  // Estadísticas calculadas desde OutfitUso
  final int vecesUsado;
  final double? tempPromedioUso;
  final DateTime? ultimoUso;

  const OutfitGuardado({
    required this.idOutfit,
    required this.fechaCreacion,
    required this.origen,
    required this.prendas,
    this.vecesUsado = 0,
    this.tempPromedioUso,
    this.ultimoUso,
  });

  /// Regla única de composición (la usan el caso de uso y el repositorio):
  /// (1 superior + 1 inferior) o (1 entero), y como máximo 1 exterior.
  static bool composicionValida(Iterable<PrendaModel> prendas) {
    int cuantas(PrendaCategoria c) =>
        prendas.where((p) => p.categoria == c).length;

    final sup = cuantas(PrendaCategoria.superior);
    final inf = cuantas(PrendaCategoria.inferior);
    final ent = cuantas(PrendaCategoria.entero);
    final ext = cuantas(PrendaCategoria.exterior);

    final conPar = sup == 1 && inf == 1 && ent == 0;
    final conEntero = ent == 1 && sup == 0 && inf == 0;
    return (conPar || conEntero) && ext <= 1;
  }

  PrendaModel? _primera(PrendaCategoria c) =>
      prendas.where((p) => p.categoria == c).firstOrNull;

  PrendaModel? get superior => _primera(PrendaCategoria.superior);
  PrendaModel? get inferior => _primera(PrendaCategoria.inferior);
  PrendaModel? get entero => _primera(PrendaCategoria.entero);
  PrendaModel? get exterior => _primera(PrendaCategoria.exterior);

  /// Prendas base (sin la capa exterior): un par, o una sola si es entero
  List<PrendaModel> get principales =>
      prendas.where((p) => p.categoria != PrendaCategoria.exterior).toList();

  bool get esEntero => entero != null;

  /// Rango de temperatura del outfit. Entero: el de la prenda. Par: intersección
  /// de superior e inferior (la capa exterior se ignora); si no se cruzan, la unión.
  ({double min, double max}) get rangoTemperatura {
    final e = entero;
    if (e != null) return (min: e.tempMin, max: e.tempMax);

    // Composición válida garantizada: hay superior e inferior
    final a = superior!;
    final b = inferior!;
    final lo = math.max(a.tempMin, b.tempMin);
    final hi = math.min(a.tempMax, b.tempMax);
    if (lo <= hi) return (min: lo, max: hi);
    return (
      min: math.min(a.tempMin, b.tempMin),
      max: math.max(a.tempMax, b.tempMax),
    );
  }

  /// Condiciones para las que sirven TODAS las prendas del outfit
  Set<String> get condicionesComunes => prendas
      .map((p) => p.condiciones.toSet())
      .reduce((a, b) => a.intersection(b));
}
