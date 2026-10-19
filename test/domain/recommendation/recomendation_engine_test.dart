import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';

void main() {
  final engine = RecommendationEngine();

  ClimaModel clima(double temp, {String condicion = 'soleado'}) => ClimaModel(
    fechaHora: DateTime(2026, 10, 14, 15),
    temperatura: temp,
    humedad: 50,
    condicion: condicion,
  );

  PrendaModel prenda(
    String tipo,
    double min,
    double max, {
    String condicion = 'soleado',
  }) => PrendaModel(
    tipo: tipo,
    imagenRuta: '/tmp/$tipo.jpg',
    tempMin: min,
    tempMax: max,
    condicionAplicable: condicion,
  );

  final prendas = [
    prenda('Polera', 18, 32),
    prenda('Poleron', 5, 17),
    prenda('Shorts', 20, 35),
    prenda('Pantalon', 5, 22),
    prenda('Chaqueta', 0, 14),
  ];

  test('TP-04: a 25 C elige polera + shorts y sin chaqueta', () {
    final outfit = engine.recommend(clima(25), prendas);

    expect(outfit.superior.tipo, 'Polera');
    expect(outfit.inferior.tipo, 'Shorts');
    expect(outfit.exterior, isNull);
  });

  test('a 8 C elige poleron + pantalon y agrega chaqueta', () {
    final outfit = engine.recommend(clima(8), prendas);

    expect(outfit.superior.tipo, 'Poleron');
    expect(outfit.inferior.tipo, 'Pantalon');
    expect(outfit.exterior?.tipo, 'Chaqueta');
  });

  test('el puntaje de temperatura decae fuera dle rango', () {
    final dentro = engine.puntajeTemperatura(20, 10, 30);
    final cerca = engine.puntajeTemperatura(32, 10, 30);
    final lejos = engine.puntajeTemperatura(50, 10, 30);

    expect(dentro, greaterThan(cerca));
    expect(cerca, greaterThan(lejos));
    expect(lejos, 0.0);
  });

  test('lanza RecommendationException si falta una categoria', () {
    expect(
      () => engine.recommend(clima(20), [prenda('Polera', 10, 30)]),
      throwsA(isA<RecommendationException>()),
    );
  });

  test('varias condiciones: puntua si alguna coincide con el clima', () {
    final engine = RecommendationEngine();
    final clima = ClimaModel(
      fechaHora: DateTime(2026, 10, 19, 12),
      temperatura: 20,
      humedad: 50,
      condicion: 'nublado',
    );
    PrendaModel p(String c) => PrendaModel(
      tipo: 'Polera',
      imagenRuta: '/x.jpg',
      tempMin: 15,
      tempMax: 25,
      condicionAplicable: c,
    );

    expect(
      engine.puntaje(clima, p('soleado,nublado')),
      engine.puntaje(clima, p('nublado')),
    );
    expect(
      engine.puntaje(clima, p('soleado,nublado')),
      greaterThan(engine.puntaje(clima, p('soleado'))),
    );
  });
}
