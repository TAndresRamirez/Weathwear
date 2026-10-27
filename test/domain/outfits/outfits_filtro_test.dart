import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/outfits/outfit_filtro.dart';

PrendaModel _p(String tipo, double min, double max, String cond) => PrendaModel(
  tipo: tipo,
  imagenRuta: '/tmp/$tipo.jpg',
  tempMin: min,
  tempMax: max,
  condicionAplicable: cond,
);

OutfitGuardado _outfit(
  int id,
  List<PrendaModel> prendas, {
  int usos = 0,
  int dia = 1,
}) => OutfitGuardado(
  idOutfit: id,
  fechaCreacion: DateTime(2026, 10, dia),
  origen: OutfitOrigen.manual,
  prendas: prendas,
  vecesUsado: usos,
);

void main() {
  // Calor: rango 20-30 (soleado). Frío: rango 5-12 (nublado, lluvia).
  final calor = _outfit(
    1,
    [_p('Polera', 18, 32, 'soleado'), _p('Shorts', 20, 35, 'soleado')],
    usos: 5,
    dia: 1,
  );
  final frio = _outfit(
    2,
    [
      _p('Poleron', 5, 15, 'nublado,lluvia'),
      _p('Pantalon', 0, 12, 'nublado,lluvia'),
    ],
    usos: 1,
    dia: 2,
  );
  final todos = [calor, frio];

  test('por defecto ordena por los últimos creados', () {
    expect(const OutfitFiltro().aplicar(todos), [frio, calor]);
  });

  test('"más usados" ordena por cantidad de usos', () {
    const f = OutfitFiltro(orden: OutfitOrden.masUsados);
    expect(f.aplicar(todos), [calor, frio]);
  });

  test('filtra por condición: todas las prendas deben servir', () {
    expect(const OutfitFiltro(condicion: 'lluvia').aplicar(todos), [frio]);
    expect(const OutfitFiltro(condicion: 'soleado').aplicar(todos), [calor]);
  });

  test('filtra por rango de temperatura cruzando el rango del outfit', () {
    expect(const OutfitFiltro(tempMin: 25, tempMax: 40).aplicar(todos), [
      calor,
    ]);
    expect(const OutfitFiltro(tempMin: 0, tempMax: 10).aplicar(todos), [frio]);
  });

  test('rangoTemperatura usa la intersección, o la unión si no se cruzan', () {
    expect(calor.rangoTemperatura, (min: 20.0, max: 32.0));

    final disjunto = _outfit(3, [
      _p('Polera', 25, 35, 'soleado'),
      _p('Pantalon', 0, 10, 'soleado'),
    ]);
    expect(disjunto.rangoTemperatura, (min: 0.0, max: 35.0));
  });
}
