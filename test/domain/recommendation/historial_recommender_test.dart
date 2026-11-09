import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/models/uso_historial.dart';
import 'package:weathwear/domain/recommendation/historial_recommender.dart';

// Datos fijos de la Tabla 5 / Tabla 13 del informe (TP-04a, TP-04c, TP-04d).
// Clima de referencia: 12 °C, 60 %, nublado. Tolerancia 1e-9.
const _tol = 1e-9;

PrendaModel _p(int id, String tipo) => PrendaModel(
  idPrenda: id,
  tipo: tipo,
  imagenRuta: '/tmp/$tipo$id.jpg',
  tempMin: 0,
  tempMax: 35,
  condicionAplicable: 'nublado',
);

final _chaqueta = _p(1, 'Chaqueta');
final _pantalon = _p(2, 'Pantalon');
final _polera = _p(3, 'Polera');
final _shorts = _p(4, 'Shorts');

// Outfits: 10 = polera + pantalón (+ chaqueta), 20 = polera + pantalón,
// 30 = polera + shorts
final _conChaqueta = [_polera, _pantalon, _chaqueta];
final _sinChaqueta = [_polera, _pantalon];
final _verano = [_polera, _shorts];

UsoHistorial _uso(
  int idOutfit,
  List<PrendaModel> prendas,
  double t,
  double h,
  String c, {
  DateTime? fecha,
}) => UsoHistorial(
  idOutfit: idOutfit,
  prendas: prendas,
  fechaUso: fecha ?? DateTime(2026, 9, 1),
  temperatura: t,
  humedad: h,
  condicion: c,
);

ClimaModel _clima(double t, double h, String c) => ClimaModel(
  idClima: 1,
  fechaHora: DateTime(2026, 9, 15, 9),
  temperatura: t,
  humedad: h,
  condicion: c,
);

void main() {
  final motor = HistorialRecommender();
  final referencia = _clima(12, 60, 'nublado');

  group('similitud (Tabla 13)', () {
    test('valores del historial H1', () {
      expect(
        motor.similitud(referencia, _uso(1, _sinChaqueta, 10, 65, 'nublado')),
        closeTo(0.9525, _tol),
      );
      expect(
        motor.similitud(referencia, _uso(1, _sinChaqueta, 13, 60, 'nublado')),
        closeTo(0.98, _tol),
      );
      expect(
        motor.similitud(referencia, _uso(1, _verano, 20, 50, 'despejado')),
        closeTo(0.575, _tol),
      );
      expect(
        motor.similitud(referencia, _uso(1, _conChaqueta, 11, 70, 'lluvia')),
        closeTo(0.715, _tol),
      );
    });

    test('la condición se compara sin mayúsculas ni espacios', () {
      expect(
        motor.similitud(referencia, _uso(1, _sinChaqueta, 12, 60, ' Nublado ')),
        closeTo(1.0, _tol),
      );
    });

    test('ΔT se satura en 30 °C', () {
      expect(
        motor.similitud(_clima(0, 60, 'nublado'), _uso(1, _verano, 40, 60, 'nublado')),
        closeTo(0.40, _tol),
      );
    });
  });

  test('TP-04a: historial H1 -> conjunto de mayor puntaje y alternativa', () {
    // Outfit 20 = U1 y U2; outfit 10 = U3 y U5; outfit 30 = U4
    final h1 = [
      _uso(20, _sinChaqueta, 10, 65, 'nublado'), // U1 0,9525
      _uso(20, _sinChaqueta, 14, 55, 'nublado'), // U2 0,9525
      _uso(10, _conChaqueta, 13, 60, 'nublado'), // U3 0,98
      _uso(30, _verano, 20, 50, 'despejado'), // U4 0,575 (bajo umbral)
      _uso(10, _conChaqueta, 11, 70, 'lluvia'), // U5 0,715 (bajo umbral)
    ];

    final r = motor.recomendar(referencia, h1);

    expect(r.length, 2); // el outfit 30 queda fuera por el umbral
    expect(r[0].idOutfit, 20);
    expect(r[0].puntaje, closeTo(1.905, _tol));
    expect(r[0].usosSimilares, 2);
    expect(r[0].justificacion,
        'Utilizaste este conjunto 2 veces con un clima similar');
    expect(r[0].outfit.superior?.tipo, 'Polera');
    expect(r[0].outfit.inferior?.tipo, 'Pantalon');
    expect(r[0].outfit.exterior, isNull);

    expect(r[1].idOutfit, 10);
    expect(r[1].puntaje, closeTo(0.98, _tol)); // U5 no cuenta
    expect(r[1].outfit.exterior?.tipo, 'Chaqueta');
    expect(r[1].justificacion,
        'Utilizaste este conjunto 1 vez con un clima similar');

    // Determinista: dos consultas idénticas dan lo mismo
    final otra = motor.recomendar(referencia, h1);
    expect(otra.map((c) => c.idOutfit), r.map((c) => c.idOutfit));
  });

  test('TP-04c: empate de puntaje -> gana el uso más reciente', () {
    final usos = [
      _uso(20, _sinChaqueta, 12, 60, 'nublado', fecha: DateTime(2026, 9, 1)),
      _uso(10, _conChaqueta, 12, 60, 'nublado', fecha: DateTime(2026, 9, 10)),
    ];

    final r = motor.recomendar(referencia, usos);

    expect(r[0].idOutfit, 10);
    expect(r[0].puntaje, closeTo(1.0, _tol));
    expect(r[1].idOutfit, 20);
  });

  test('TP-04d: s = 0,75 se considera; s = 0,735 se descarta', () {
    final r = motor.recomendar(referencia, [
      _uso(10, _conChaqueta, 12, 60, 'lluvia'), // 0,75
      _uso(20, _sinChaqueta, 12, 70, 'lluvia'), // 0,735
    ]);

    expect(r.map((c) => c.idOutfit), [10]);
    expect(r.single.puntaje, closeTo(0.75, _tol));
  });

  test('solo cuentan los k = 5 usos más similares', () {
    final usos = [
      // 5 usos casi idénticos del outfit 10
      for (var i = 0; i < 5; i++) _uso(10, _conChaqueta, 12, 60, 'nublado'),
      // 3 usos del outfit 20, algo menos similares: quedan fuera del top 5
      for (var i = 0; i < 3; i++) _uso(20, _sinChaqueta, 13, 60, 'nublado'),
    ];

    final r = motor.recomendar(referencia, usos);

    expect(r.map((c) => c.idOutfit), [10]);
    expect(r.single.usosSimilares, 5);
  });

  test('sin usos similares (o sin historial) -> vacío: aplica el respaldo', () {
    expect(motor.recomendar(referencia, const []), isEmpty);
    expect(
      motor.recomendar(referencia, [_uso(30, _verano, 28, 30, 'despejado')]),
      isEmpty,
    );
  });
}
