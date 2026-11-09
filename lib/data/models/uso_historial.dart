import 'package:weathwear/data/models/prenda_model.dart';

/// Un uso registrado (OutfitUso) con el clima de ese momento: la unidad de
/// historial que compara el motor de recomendación (CU-03, RF-05).
class UsoHistorial {
  final int idOutfit;

  /// Prendas del outfit usado, ordenadas: superior, inferior, entero, exterior
  final List<PrendaModel> prendas;
  final DateTime fechaUso;
  final double temperatura;
  final double humedad;
  final String condicion;

  const UsoHistorial({
    required this.idOutfit,
    required this.prendas,
    required this.fechaUso,
    required this.temperatura,
    required this.humedad,
    required this.condicion,
  });
}
