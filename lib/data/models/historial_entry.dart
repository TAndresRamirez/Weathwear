import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';

// Un outfit recomendado en el pasado, con el clima qeu lo origino
class HistorialEntry {
  final ClimaModel clima;
  final DateTime fechaGeneracion;
  final double similitud;
  final List<PrendaModel> prendas;

  const HistorialEntry({
    required this.clima,
    required this.fechaGeneracion,
    required this.similitud,
    required this.prendas,
  });
}
