import 'package:weathwear/data/models/prenda_model.dart';

// Conjunto recomendado: una prenda superior + una inferior y opcionalmente una capa exterior
class Outfit {
  final PrendaModel superior;
  final PrendaModel inferior;
  final PrendaModel? exterior;

  // Puntaje promedio de las prendas incluidas
  // Se guarda luego en Recomendacion.nivel_similitud
  final double similitud;

  const Outfit({
    required this.superior,
    required this.inferior,
    this.exterior,
    required this.similitud,
  });

  List<PrendaModel> get prendas => [superior, inferior, ?exterior];
}
