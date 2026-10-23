import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/historial_entry.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/presentation/screens/historial_screen.dart';

Widget _wrap(Future<List<HistorialEntry>> Function() loader) => MaterialApp(
  home: Scaffold(body: HistorialScreen(loader: loader)),
);

void main() {
  testWidgets('muestra clima, prendas y afinidad de cada outfit', (t) async {
    await t.pumpWidget(
      _wrap(
        () async => [
          HistorialEntry(
            clima: ClimaModel(
              fechaHora: DateTime(2026, 10, 20, 9),
              temperatura: 12,
              humedad: 60,
              condicion: 'nublado',
            ),
            fechaGeneracion: DateTime(2026, 10, 20, 9, 5),
            similitud: 0.9,
            prendas: const [
              PrendaModel(
                tipo: 'Poleron',
                imagenRuta: '/no/existe.jpg',
                tempMin: 5,
                tempMax: 18,
                condicionAplicable: 'nublado',
              ),
            ],
          ),
        ],
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('12.0°C · nublado · 60%'), findsOneWidget);
    expect(find.text('Poleron'), findsOneWidget);
    expect(find.text('Afinidad: 90%'), findsOneWidget);
  });

  testWidgets('estado vacío', (t) async {
    await t.pumpWidget(_wrap(() async => []));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('historial_vacio')), findsOneWidget);
  });
}
