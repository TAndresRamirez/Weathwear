import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

class PrendaModel {
  final int? idPrenda;
  final String tipo;
  final String imagenRuta;
  final double tempMin;
  final double tempMax;
  final String condicionAplicable;

  const PrendaModel({
    this.idPrenda,
    required this.tipo,
    required this.imagenRuta,
    required this.tempMin,
    required this.tempMax,
    required this.condicionAplicable,
  });

  PrendaCategoria get categoria => PrendaCategoriaMapper.fromTipo(tipo);

  Map<String, Object?> toMap() => {
    if (idPrenda != null) 'id_prenda': idPrenda,
    'tipo': tipo,
    'imagen_ruta': imagenRuta,
    'temp_min': tempMin,
    'temp_max': tempMax,
    'condicion_aplicable': condicionAplicable,
  };

  factory PrendaModel.fromMap(Map<String, Object?> map) => PrendaModel(
    idPrenda: map['id_prenda'] as int?,
    tipo: map['tipo'] as String,
    imagenRuta: map['imagen_ruta'] as String,
    // num -> double: SQLite puede devolver int si se gurado un entero
    tempMin: (map['temp_min'] as num).toDouble(),
    tempMax: (map['temp_max'] as num).toDouble(),
    condicionAplicable: map['condicion_aplicable'] as String,
  );
}
