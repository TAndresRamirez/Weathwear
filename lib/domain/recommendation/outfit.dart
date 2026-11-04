import 'package:weathwear/data/models/prenda_model.dart';

// Conjunto recomendado. Dos formas válidas:
//  - superior + inferior, o
//  - una prenda entera,
// más una capa exterior opcional en ambos casos.
class Outfit {
  final PrendaModel? superior;
  final PrendaModel? inferior;
  final PrendaModel? entero;
  final PrendaModel? exterior;

  // Puntaje promedio de las prendas incluidas
  // Se guarda luego en Recomendacion.nivel_similitud
  final double similitud;

  const Outfit({
    this.superior,
    this.inferior,
    this.entero,
    this.exterior,
    required this.similitud,
  }) : assert(
         entero != null
             ? (superior == null && inferior == null)
             : (superior != null && inferior != null),
         'Un outfit es superior + inferior, o una prenda entera',
       );

  bool get esEntero => entero != null;

  // Prendas base (sin la capa exterior), en orden de visualización
  List<PrendaModel> get principales => [?superior, ?inferior, ?entero];

  // Orden de visualización: superior, inferior, entero, exterior
  List<PrendaModel> get prendas => [...principales, ?exterior];
}
