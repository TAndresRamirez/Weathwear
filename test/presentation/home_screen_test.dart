import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/presentation/screens/home_screen.dart';

Widget _wrap(Future<ClimaModel?> Function({bool force}) loader) => MaterialApp(
  home: Scaffold(body: HomeScreen(loader: loader)),
);

void main() {
  testWidgets('TP-06: muestra temperatura, condicion y humedad', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ({bool force = false}) async => ClimaModel(
          fechaHora: DateTime(2026, 10, 15, 12),
          temperatura: 21.4,
          humedad: 36,
          condicion: 'soleado',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('21.4°C'), findsOneWidget);
    expect(find.byKey(const Key('clima_condicion')), findsOneWidget);
    expect(find.text('soleado'), findsOneWidget);
    expect(find.text('Humedad: 36%'), findsOneWidget);
  });

  testWidgets('muestra estado vacio si no hay datos', (tester) async {
    await tester.pumpWidget(_wrap(({bool force = false}) async => null));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin datos climaticos'), findsOneWidget);
  });

  testWidgets('muestra estado vacio si la carga falla', (tester) async {
    await tester.pumpWidget(
      _wrap(({bool force = false}) async => throw Exception('boom')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin datos climaticos'), findsOneWidget);
  });
}
