import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/presentation/screens/prendas_screen.dart';

PrendaModel _p(String tipo) => PrendaModel(
  tipo: tipo,
  imagenRuta: '/no/existe.jpg',
  tempMin: 15,
  tempMax: 25,
  condicionAplicable: 'soleado',
);

Widget _wrap({
  List<PrendaModel> prendas = const [],
  List<OutfitGuardado> outfits = const [],
}) => MaterialApp(
  home: PrendasScreen(
    loader: () async => prendas,
    outfitsLoader: () async => outfits,
    climaLoader: () async => ClimaModel(
      idClima: 1,
      fechaHora: DateTime(2026, 10, 26, 12),
      temperatura: 20, // centro del rango 15-25: afinidad máxima
      humedad: 50,
      condicion: 'soleado',
    ),
  ),
);

OutfitGuardado _outfit() => OutfitGuardado(
  idOutfit: 1,
  fechaCreacion: DateTime(2026, 10, 26),
  origen: OutfitOrigen.manual,
  prendas: [_p('Polera'), _p('Pantalon')],
);

void main() {
  testWidgets('estados vacíos de prendas y outfits', (t) async {
    await t.pumpWidget(_wrap());
    await t.pumpAndSettle();

    expect(find.text('Aún no tienes prendas registradas.'), findsOneWidget);
    expect(find.textContaining('Aún no tienes outfits'), findsOneWidget);
  });

  testWidgets('muestra 4 prendas por página y pasa a la siguiente', (t) async {
    final prendas = [
      _p('Polera'),
      _p('Poleron'),
      _p('Chaqueta'),
      _p('Pantalon'),
      _p('Shorts'),
    ];
    await t.pumpWidget(_wrap(prendas: prendas));
    await t.pumpAndSettle();

    expect(find.text('Polera'), findsOneWidget);
    expect(find.text('Shorts'), findsNothing);

    await t.drag(find.byType(PageView).first, const Offset(-500, 0));
    await t.pumpAndSettle();

    expect(find.text('Shorts'), findsOneWidget);
  });

  testWidgets('el outfit muestra afinidad y abre el detalle al tocarlo', (
    t,
  ) async {
    await t.pumpWidget(_wrap(outfits: [_outfit()]));
    await t.pumpAndSettle();

    expect(find.text('Afinidad 100%'), findsOneWidget);

    await t.tap(find.text('Afinidad 100%'));
    await t.pumpAndSettle();

    expect(find.text('Usar hoy'), findsOneWidget);
    expect(find.text('Sin usos aún'), findsOneWidget);
  });
}
