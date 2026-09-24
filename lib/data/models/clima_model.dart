class ClimaModel {
  final int? idClima;
  final DateTime fechaHora;
  final double temperatura;
  final double humedad;
  final String condicion;

  const ClimaModel({
    this.idClima,
    required this.fechaHora,
    required this.temperatura,
    required this.humedad,
    required this.condicion,
  });

  Map<String, Object?> toMap() => {
    if (idClima != null) 'id_clima': idClima,
    'fecha_hora': fechaHora.toIso8601String(),
    'temperatura': temperatura,
    'humedad': humedad,
    'condicion': condicion,
  };

  factory ClimaModel.fromMap(Map<String, Object?> map) => ClimaModel(
    idClima: map['id_clima'] as int?,
    fechaHora: DateTime.parse(map['fecha_hora'] as String),
    temperatura: map['temperatura'] as double,
    humedad: map['humedad'] as double,
    condicion: map['condicion'] as String,
  );
}
