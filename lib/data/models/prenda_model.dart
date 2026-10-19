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

  // Condiciones aplicables como lista (la columna guarda "lloviendo","nublado")
  List<String> get condiciones => condicionAplicable
      .split(",")
      .map((c) => c.trim().toLowerCase())
      .where((c) => c.isNotEmpty)
      .toList();

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

  /// Copia con cambios. La imagen y el id no cambian al editar una prenda.
  PrendaModel copyWith({
    String? tipo,
    double? tempMin,
    double? tempMax,
    String? condicionAplicable,
  }) => PrendaModel(
    idPrenda: idPrenda,
    tipo: tipo ?? this.tipo,
    imagenRuta: imagenRuta,
    tempMin: tempMin ?? this.tempMin,
    tempMax: tempMax ?? this.tempMax,
    condicionAplicable: condicionAplicable ?? this.condicionAplicable,
  );
}
