import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/presentation/screens/crear_outfit_screen.dart';

PrendaModel _p(int id, String tipo) => PrendaModel(
  idPrenda: id,
  tipo: tipo,
  imagenRuta: '/no/existe.jpg',
  tempMin: 15,
  tempMax: 25,
  condicionAplicable: 'soleado',
);

void main() {
  testWidgets('el botón se habilita con superior + inferior y guarda', (
    t,
  ) async {
    List<PrendaModel>? guardadas;
    await t.pumpWidget(
      MaterialApp(
        home: CrearOutfitScreen(
          prendasLoader: () async => [
            _p(1, 'Polera'),
            _p(2, 'Pantalon'),
            _p(3, 'Chaqueta'),
          ],
          guardar: (prendas) async {
            guardadas = prendas;
            return 1;
          },
        ),
      ),
    );
    await t.pumpAndSettle();

    final boton = find.widgetWithText(FilledButton, 'Guardar outfit');
    expect(t.widget<FilledButton>(boton).onPressed, isNull);

    await t.tap(find.text('Polera'));
    await t.pump();
    expect(t.widget<FilledButton>(boton).onPressed, isNull); // falta inferior

    await t.tap(find.text('Pantalon'));
    await t.pump();
    expect(t.widget<FilledButton>(boton).onPressed, isNotNull);

    await t.tap(boton);
    await t.pumpAndSettle();

    expect(guardadas?.map((p) => p.tipo), ['Polera', 'Pantalon']);
  });
}
