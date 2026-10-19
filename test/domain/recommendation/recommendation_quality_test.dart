// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';

// Criterio de calidad del motor (TP-04): propiedades que deben cumplirse
// en "todo" el rango de temperatura. no solo en casos puntuales
void main() {
  final engine = RecommendationEngine();

  PrendaModel p(String tipo, double min, double max, String cond) =>
      PrendaModel(
        tipo: tipo,
        imagenRuta: '/tmp/$tipo.jpg',
        tempMin: min,
        tempMax: max,
        condicionAplicable: cond,
      );

  // Guardarropa de referencia => rangos: solapados, y condiciones distintas a proposito
  final chaqueta = p('Chaqueta', 0, 15, 'lluvia');
  final guardarropa = [
    p('Polera', 16, 35, 'soleado'),
    p('Poleron', 5, 18, 'nublado'),
    p('Shorts', 20, 40, 'soleado'),
    p('Pantalon', -5, 24, 'nublado'),
    chaqueta,
  ];

  const condiciones = ['soleado', 'nublado', 'lluvia'];
  final temperaturas = [for (var t = -5.0; t <= 40.0; t += 0.5) t];

  ClimaModel clima(double t, String c) => ClimaModel(
    fechaHora: DateTime(2026, 10, 15, 12),
    temperatura: t,
    humedad: 50,
    condicion: c,
  );

  bool cubre(PrendaModel x, double t) => t >= x.tempMin && t <= x.tempMax;

  bool hayCubierta(PrendaCategoria cat, double t) => guardarropa.any(
    (x) => PrendaCategoriaMapper.fromTipo(x.tipo) == cat && cubre(x, t),
  );

  test('criterio A: adecuacion termica 100% en escenarios cubiertos', () {
    var evaluados = 0;
    final fallos = <String>[];

    for (final c in condiciones) {
      for (final t in temperaturas) {
        final outfit = engine.recommend(clima(t, c), guardarropa);

        // D: la similitud siempre es un valor normalizado
        expect(outfit.similitud, inInclusiveRange(0.0, 1.0));

        for (final (cat, elegida) in [
          (PrendaCategoria.superior, outfit.superior),
          (PrendaCategoria.inferior, outfit.inferior),
        ]) {
          if (!hayCubierta(cat, t)) {
            continue; // sin candidata valida no se evalua
          }
          evaluados++;
          if (!cubre(elegida, t)) {
            fallos.add('$t C / $c: ${elegida.tipo} fuera de su rango');
          }
        }
      }
    }

    // Porcentaje de adecuacion medio
    final ok = evaluados - fallos.length;
    print(
      'Adecuacion termica: $ok/$evaluados (${(100 * ok / evaluados).toStringAsFixed(1)})',
    );

    expect(fallos, isEmpty, reason: fallos.take(5).join('\n'));
  });

  test(
    'criterio B: a mayor temperatura la prenda superior no es mas abrigada',
    () {
      for (final c in condiciones) {
        var tempMaxAnterior = double.negativeInfinity;
        for (final t in temperaturas) {
          final sup = engine.recommend(clima(t, c), guardarropa).superior;

          expect(
            sup.tempMax,
            greaterThanOrEqualTo(tempMaxAnterior),
            reason: '$t C / $c: cambio a una prenda mas abrigada',
          );
          tempMaxAnterior = sup.tempMax;
        }
      }
    },
  );

  test(
    'criterio C: la chaqueta entra si cubre la temperatura y no si hace calor',
    () {
      for (final c in condiciones) {
        for (final t in temperaturas) {
          final outfit = engine.recommend(clima(t, c), guardarropa);

          if (cubre(chaqueta, t)) {
            expect(outfit.exterior, isNotNull, reason: '$t C / $c');
          }
          if (t > chaqueta.tempMax + RecommendationEngine.toleranciaGrados) {
            expect(outfit.exterior, isNull, reason: '$t C / $c');
          }
        }
      }
    },
  );
}
