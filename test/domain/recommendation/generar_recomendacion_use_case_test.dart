import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ClimaRepository climaRepo;
  late PrendaRepository prendaRepo;
  final ahora = DateTime(2026, 10, 14, 15);

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE Clima (
        id_clima INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL, temperatura REAL NOT NULL,
        humedad REAL NOT NULL, condicion TEXT NOT NULL)
    ''');
    await db.execute('''
      CREATE TABLE Prenda (
        id_prenda INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL, imagen_ruta TEXT NOT NULL,
        temp_min REAL NOT NULL, temp_max REAL NOT NULL,
        condicion_aplicable TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        CHECK (temp_min <= temp_max))
    ''');
    await db.execute('''
      CREATE TABLE Recomendacion (
        id_recomendacion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_clima INTEGER NOT NULL, id_prenda INTEGER NOT NULL,
        fecha_generacion TEXT NOT NULL, nivel_similitud REAL,
        FOREIGN KEY (id_clima) REFERENCES Clima(id_clima)
          ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (id_prenda) REFERENCES Prenda(id_prenda)
          ON DELETE RESTRICT ON UPDATE CASCADE)
    ''');
    SqliteHelper.setTestDatabase(db);
    climaRepo = ClimaRepository();
    prendaRepo = PrendaRepository();
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  GenerarRecomendacionUseCase buildUseCase() => GenerarRecomendacionUseCase(
    climaRepo,
    prendaRepo,
    RecomendacionRepository(),
    now: () => ahora,
  );

  Future<void> seedPrendas() async {
    for (final (tipo, min, max) in [
      ('Polera', 18.0, 32.0),
      ('Shorts', 20.0, 35.0),
    ]) {
      await prendaRepo.insert(
        PrendaModel(
          tipo: tipo,
          imagenRuta: '/tmp/$tipo.jpg',
          tempMin: min,
          tempMax: max,
          condicionAplicable: 'soleado',
        ),
      );
    }
  }

  Future<void> seedClima(DateTime fecha) => climaRepo.insert(
    ClimaModel(
      fechaHora: fecha,
      temperatura: 25,
      humedad: 40,
      condicion: 'soleado',
    ),
  );

  test('genera outfit y persiste una fila por prenda', () async {
    await seedPrendas();
    await seedClima(ahora);

    final r = await buildUseCase()();

    expect(r.outfit.superior.tipo, 'Polera');
    expect(r.climaDesactualizado, false);
    final rows = await db.query('Recomendacion');
    expect(rows.length, 2);
    expect(rows.map((e) => e['fecha_generacion']).toSet().length, 1);
  });

  test('marca el clima como desactualizado si supera 3h', () async {
    await seedPrendas();
    await seedClima(ahora.subtract(const Duration(hours: 5)));

    final r = await buildUseCase()();

    expect(r.climaDesactualizado, true);
  });

  test('sin datos de clima lanza RecomendationException', () async {
    await seedPrendas();

    expect(() => buildUseCase()(), throwsA(isA<RecommendationException>()));
  });

  test('llamar dos veces con el mismo clima no duplica el historial', () async {
    await seedPrendas();
    await seedClima(ahora);

    await buildUseCase()();
    await buildUseCase()();

    expect((await db.query('Recomendacion')).length, 2); // 1 outfit = 2 filas
  });
}
