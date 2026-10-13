import 'package:weathwear/data/models/prenda_model.dart';

// Conjunto recomendado: una prenda superior + una inferior y opcionalmente una capa exterior
class Outfit {
  final PrendaModel superior;
  final PrendaModel inferior;
  final PrendaModel? exterior;

  const Outfit({required this.superior, required this.inferior, this.exterior});

  List<PrendaModel> get prendas => [superior, inferior, ?exterior];
}
