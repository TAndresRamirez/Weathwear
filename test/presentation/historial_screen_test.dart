import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/historial_entry.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/presentation/screens/historial_screen.dart';

Widget _wrap(
  Future<List<HistorialEntry>> Function() loader, {
  Duration intervalo = const Duration(seconds: 3),
}) => MaterialApp(
  home: Scaffold(
    body: HistorialScreen(loader: loader, intervaloRotacion: intervalo),
  ),
);

PrendaModel _prenda(String tipo) => PrendaModel(
  tipo: tipo,
  imagenRuta: '/no/existe.jpg',
  tempMin: 5,
  tempMax: 18,
  condicionAplicable: 'nublado',
);

HistorialEntry _entry(List<PrendaModel> prendas, {double? sensacion}) =>
    HistorialEntry(
      clima: ClimaModel(
        fechaHora: DateTime(2026, 10, 20, 9),
        temperatura: 12,
        humedad: 60,
        condicion: 'nublado',
        sensacionTermica: sensacion,
      ),
      fechaGeneracion: DateTime(2026, 10, 20, 9, 5),
      similitud: 0.9,
      prendas: prendas,
    );

void main() {
  testWidgets('muestra clima y prendas, pero no la afinidad', (t) async {
    await t.pumpWidget(
      _wrap(
        () async => [
          _entry([_prenda('Poleron')]),
        ],
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('12.0°C · nublado'), findsOneWidget);
    expect(find.text('Humedad 60%'), findsOneWidget);
    expect(find.text('Poleron'), findsOneWidget);
    expect(find.textContaining('Afinidad'), findsNothing);
  });

  testWidgets('sensación y viento solo aparecen si existen', (t) async {
    await t.pumpWidget(
      _wrap(
        () async => [
          _entry([_prenda('Polera')], sensacion: 10.5),
        ],
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Sensación 10.5°C'), findsOneWidget);
    expect(find.textContaining('Viento'), findsNothing);
  });

  testWidgets('con 3 prendas alterna superior+inferior y exterior', (t) async {
    await t.pumpWidget(
      _wrap(
        () async => [
          _entry([_prenda('Polera'), _prenda('Pantalon'), _prenda('Chaqueta')]),
        ],
        intervalo: const Duration(seconds: 1),
      ),
    );
    await t.pump(); // resuelve el Future
    await t.pump();

    expect(find.text('Polera'), findsOneWidget);
    expect(find.text('Chaqueta'), findsNothing);

    await t.pump(const Duration(seconds: 1)); // dispara el timer
    await t.pump(const Duration(milliseconds: 400)); // termina la transición

    expect(find.text('Chaqueta'), findsOneWidget);
    expect(find.text('Polera'), findsNothing);
  });

  testWidgets('estado vacío', (t) async {
    await t.pumpWidget(_wrap(() async => []));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('historial_vacio')), findsOneWidget);
  });
}
