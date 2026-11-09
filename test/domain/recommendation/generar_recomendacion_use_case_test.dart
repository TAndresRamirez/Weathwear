import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
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
    await SqliteHelper.crearTablasOutfit(db); // historial de usos (OutfitUso)
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

    expect(r.outfit.superior?.tipo, 'Polera');
    expect(r.climaDesactualizado, false);
    final rows = await db.query('Recomendacion');
    expect(rows.length, 2);
    expect(rows.map((e) => e['fecha_generacion']).toSet().length, 1);
  });

  test('sin historial aplica el respaldo por rango y lo justifica', () async {
    await seedPrendas();
    await seedClima(ahora);

    final r = await buildUseCase()();

    expect(r.desdeHistorial, isFalse);
    expect(r.alternativa, isNull);
    expect(r.justificacion, contains('rango de temperatura'));
  });

  test('con un uso de clima similar recomienda ese outfit (historial)', () async {
    await seedPrendas();
    // Pantalón: fuera de rango a 25 °C, el respaldo nunca lo elegiría
    final idPantalon = await prendaRepo.insert(
      const PrendaModel(
        tipo: 'Pantalon',
        imagenRuta: '/tmp/Pantalon.jpg',
        tempMin: 0,
        tempMax: 15,
        condicionAplicable: 'nublado',
      ),
    );
    final idPolera = (await prendaRepo.getAll())
        .firstWhere((p) => p.tipo == 'Polera')
        .idPrenda!;
    final outfitRepo = OutfitRepository();
    final idOutfit = await outfitRepo.insert(idsPrenda: [idPolera, idPantalon]);
    // Uso de ayer con un clima casi igual al actual (25 °C, 40 %, soleado)
    final idClimaAyer = await climaRepo.insert(
      ClimaModel(
        fechaHora: ahora.subtract(const Duration(days: 1)),
        temperatura: 24,
        humedad: 45,
        condicion: 'soleado',
      ),
    );
    await outfitRepo.registrarUso(
      idOutfit: idOutfit,
      idClima: idClimaAyer,
      fecha: ahora.subtract(const Duration(days: 1)),
    );
    await seedClima(ahora);

    final r = await buildUseCase()();

    expect(r.desdeHistorial, isTrue);
    expect(r.historial!.idOutfit, idOutfit);
    expect(r.outfit.inferior?.tipo, 'Pantalon');
    expect(
      r.justificacion,
      'Utilizaste este conjunto 1 vez con un clima similar',
    );
    // También queda en Recomendacion (trazabilidad)
    expect((await db.query('Recomendacion')).length, 2);
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
