import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/presentation/screens/editar_prenda_screen.dart';

// Fake: no toca la BD, solo registra qué prendas se desactivaron
class _FakeRepo extends PrendaRepository {
  final List<int> desactivados = [];

  @override
  Future<int> desactivar(int id) async {
    desactivados.add(id);
    return 1;
  }
}

const _prenda = PrendaModel(
  idPrenda: 7,
  tipo: 'Polera',
  imagenRuta: '/no/existe.jpg',
  tempMin: 15,
  tempMax: 25,
  condicionAplicable: 'soleado',
);

void main() {
  testWidgets('eliminar pide confirmación y desactiva la prenda', (t) async {
    final repo = _FakeRepo();
    await t.pumpWidget(
      MaterialApp(
        home: EditarPrendaScreen(prenda: _prenda, repository: repo),
      ),
    );

    await t.tap(find.byTooltip('Eliminar prenda'));
    await t.pumpAndSettle();
    expect(repo.desactivados, isEmpty); // aún no confirmó

    await t.tap(find.text('Eliminar'));
    await t.pumpAndSettle();

    expect(repo.desactivados, [7]);
  });

  testWidgets('cancelar la confirmación no elimina nada', (t) async {
    final repo = _FakeRepo();
    await t.pumpWidget(
      MaterialApp(
        home: EditarPrendaScreen(prenda: _prenda, repository: repo),
      ),
    );

    await t.tap(find.byTooltip('Eliminar prenda'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();

    expect(repo.desactivados, isEmpty);
  });
}
