import 'dart:math' as math;

import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

class OutfitOrigen {
  OutfitOrigen._();
  static const String recomendacion = 'recomendacion';
  static const String manual = 'manual';
}

/// Outfit persistido (no confundir con `Outfit`, el resultado del motor).
/// [prendas] viene ordenada: superior, inferior y, si existe, exterior.
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

  PrendaModel get superior =>
      prendas.firstWhere((p) => p.categoria == PrendaCategoria.superior);

  PrendaModel get inferior =>
      prendas.firstWhere((p) => p.categoria == PrendaCategoria.inferior);

  PrendaModel? get exterior =>
      prendas.where((p) => p.categoria == PrendaCategoria.exterior).firstOrNull;

  /// Rango de temperatura del outfit: intersección de superior e inferior
  /// (la capa exterior es opcional y se ignora). Si no se cruzan, usa la unión.
  ({double min, double max}) get rangoTemperatura {
    final a = superior;
    final b = inferior;
    final lo = math.max(a.tempMin, b.tempMin);
    final hi = math.min(a.tempMax, b.tempMax);
    if (lo <= hi) return (min: lo, max: hi);
    return (
      min: math.min(a.tempMin, b.tempMin),
      max: math.max(a.tempMax, b.tempMax),
    );
  }
}
