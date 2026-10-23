class ClimaModel {
  final int? idClima;
  final DateTime fechaHora;
  final double temperatura;
  final double humedad;
  final String condicion;
  final double? sensacionTermica;
  final double? vientoKmh;

  const ClimaModel({
    this.idClima,
    required this.fechaHora,
    required this.temperatura,
    required this.humedad,
    required this.condicion,
    this.sensacionTermica,
    this.vientoKmh,
  });

  Map<String, Object?> toMap() => {
    if (idClima != null) 'id_clima': idClima,
    'fecha_hora': fechaHora.toIso8601String(),
    'temperatura': temperatura,
    'humedad': humedad,
    'condicion': condicion,
    if (sensacionTermica != null) 'sensacion_termica': sensacionTermica,
    if (vientoKmh != null) 'viento_kmh': vientoKmh,
  };

  factory ClimaModel.fromMap(Map<String, Object?> map) => ClimaModel(
    idClima: map['id_clima'] as int?,
    fechaHora: DateTime.parse(map['fecha_hora'] as String),
    temperatura: (map['temperatura'] as num).toDouble(),
    humedad: map['humedad'] as double,
    condicion: map['condicion'] as String,
    sensacionTermica: (map['sensacion_termica'] as num?)?.toDouble(),
    vientoKmh: (map['viento_kmh'] as num?)?.toDouble(),
  );
}
