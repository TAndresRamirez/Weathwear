import 'package:weathwear/data/models/outfit_guardado.dart';

enum OutfitOrden { recientes, masUsados }

/// Filtros de la pestaña Prendas. Función pura: no toca la BD.
class OutfitFiltro {
  const OutfitFiltro({
    this.condicion,
    this.tempMin,
    this.tempMax,
    this.orden = OutfitOrden.recientes,
  });

  /// Todas las prendas del outfit deben servir para esta condición
  final String? condicion;

  /// El rango de temperatura del outfit debe cruzarse con [tempMin, tempMax]
  final double? tempMin;
  final double? tempMax;

  final OutfitOrden orden;

  List<OutfitGuardado> aplicar(List<OutfitGuardado> outfits) {
    final lista = outfits.where(_cumple).toList();
    lista.sort(_comparar);
    return lista;
  }

  bool _cumple(OutfitGuardado o) {
    final c = condicion?.toLowerCase();
    if (c != null && !o.prendas.every((p) => p.condiciones.contains(c))) {
      return false;
    }
    final r = o.rangoTemperatura;
    if (tempMin != null && r.max < tempMin!) return false;
    if (tempMax != null && r.min > tempMax!) return false;
    return true;
  }

  int _comparar(OutfitGuardado a, OutfitGuardado b) {
    if (orden == OutfitOrden.masUsados) {
      final porUso = b.vecesUsado.compareTo(a.vecesUsado);
      if (porUso != 0) return porUso;
    }
    final porFecha = b.fechaCreacion.compareTo(a.fechaCreacion);
    return porFecha != 0 ? porFecha : b.idOutfit.compareTo(a.idOutfit);
  }
}
