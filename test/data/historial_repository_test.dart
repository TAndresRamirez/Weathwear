import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE Clima (
        id_clima INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL, temperatura REAL NOT NULL,
        humedad REAL NOT NULL, condicion TEXT NOT NULL,
        sensacion_termica REAL, viento_kmh REAL)''');
    await db.execute('''
      CREATE TABLE Prenda (
        id_prenda INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL, imagen_ruta TEXT NOT NULL,
        temp_min REAL NOT NULL, temp_max REAL NOT NULL,
        condicion_aplicable TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1)''');
    await db.execute('''
      CREATE TABLE Recomendacion (
        id_recomendacion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_clima INTEGER NOT NULL, id_prenda INTEGER NOT NULL,
        fecha_generacion TEXT NOT NULL, nivel_similitud REAL,
        FOREIGN KEY (id_clima) REFERENCES Clima(id_clima),
        FOREIGN KEY (id_prenda) REFERENCES Prenda(id_prenda))''');
    SqliteHelper.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  test('getHistorial devuelve un solo outfit por día: el último', () async {
    final idClima = await ClimaRepository().insert(
      ClimaModel(
        fechaHora: DateTime(2026, 10, 20, 9),
        temperatura: 18,
        humedad: 50,
        condicion: 'soleado',
      ),
    );
    final prendaRepo = PrendaRepository();
    Future<PrendaModel> crear(String tipo) async {
      final id = await prendaRepo.insert(
        PrendaModel(
          tipo: tipo,
          imagenRuta: '/tmp/$tipo.jpg',
          tempMin: 10,
          tempMax: 30,
          condicionAplicable: 'soleado',
        ),
      );
      return (await prendaRepo.getById(id))!;
    }

    final polera = await crear('Polera');
    final pantalon = await crear('Pantalon');
    final repo = RecomendacionRepository();

    for (final (hora, sim) in [(8, 0.6), (13, 0.7), (19, 0.95)]) {
      await repo.insertOutfit(
        idClima: idClima,
        outfit: Outfit(superior: polera, inferior: pantalon, similitud: sim),
        fecha: DateTime(2026, 10, 20, hora),
      );
    }

    final historial = await repo.getHistorial();

    expect(historial.length, 1);
    expect(historial.first.similitud, 0.95); // el de las 19:00
    expect(historial.first.prendas.length, 2);
  });
}
