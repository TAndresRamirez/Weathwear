import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';
import 'package:weathwear/presentation/screens/home_screen.dart';

Widget _wrap(
  Future<ClimaModel?> Function({bool force}) loader, {
  Future<RecomendacionResultado> Function()? recomendar,
}) => MaterialApp(
  home: Scaffold(
    body: HomeScreen(
      loader: loader,
      // Por defecto simula "sin prendas" para no tocar la BD real
      recomendar:
          recomendar ??
          () async => throw const RecommendationException('Sin prendas'),
    ),
  ),
);

ClimaModel _clima() => ClimaModel(
  idClima: 1,
  fechaHora: DateTime(2026, 10, 16, 12),
  temperatura: 21.4,
  humedad: 36,
  condicion: 'soleado',
);

PrendaModel _prenda(String tipo) => PrendaModel(
  tipo: tipo,
  imagenRuta: '/no/existe.jpg',
  tempMin: 15,
  tempMax: 25,
  condicionAplicable: 'soleado',
);

void main() {
  testWidgets('TP-06: muestra temperatura, condicion y humedad', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(({bool force = false}) async => _clima()));

    // Primer frame: spinner mientras el Future no resuelve
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('21.4°C'), findsOneWidget);
    expect(find.byKey(const Key('clima_condicion')), findsOneWidget);
    expect(find.text('soleado'), findsOneWidget);
    expect(find.text('Humedad'), findsOneWidget);
    expect(find.text('36%'), findsOneWidget);
  });

  testWidgets('muestra estado vacio si no hay datos', (tester) async {
    await tester.pumpWidget(_wrap(({bool force = false}) async => null));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin datos climáticos'), findsOneWidget);
  });

  testWidgets('muestra estado vacio si la carga falla', (tester) async {
    await tester.pumpWidget(
      _wrap(({bool force = false}) async => throw Exception('boom')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin datos climáticos'), findsOneWidget);
  });

  testWidgets('TP-07: muestra las prendas recomendadas', (tester) async {
    final clima = _clima();

    await tester.pumpWidget(
      _wrap(
        ({bool force = false}) async => clima,
        recomendar: () async => RecomendacionResultado(
          Outfit(
            superior: _prenda('Polera'),
            inferior: _prenda('Pantalon'),
            similitud: 0.9,
          ),
          clima,
          false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polera'), findsOneWidget);
    expect(find.text('Pantalon'), findsOneWidget);
    expect(find.text('Afinidad: 90%'), findsOneWidget);
  });

  testWidgets('sin prendas muestra el mensaje y conserva el clima', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(({bool force = false}) async => _clima()));
    await tester.pumpAndSettle();

    expect(find.text('Sin prendas'), findsOneWidget);
    expect(find.text('21.4°C'), findsOneWidget);
  });
}
