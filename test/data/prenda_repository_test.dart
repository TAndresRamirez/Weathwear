import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late PrendaRepository repo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE Prenda (
        id_prenda INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        imagen_ruta TEXT NOT NULL,
        temp_min REAL NOT NULL,
        temp_max REAL NOT NULL,
        condicion_aplicable TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        CHECK (temp_min <= temp_max)
      )
    ''');
    SqliteHelper.setTestDatabase(db);
    repo = PrendaRepository();
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  PrendaModel prenda(String tipo, {double min = 10, double max = 20}) =>
      PrendaModel(
        tipo: tipo,
        imagenRuta: '/tpm/$tipo.jpg',
        tempMin: min,
        tempMax: max,
        condicionAplicable: 'soleado',
      );

  test('TP-05: insert y getById persisten y recuperan la prenda', () async {
    final id = await repo.insert(prenda('Polera'));
    final result = await repo.getById(id);

    expect(result, isNotNull);
    expect(result!.tipo, 'Polera');
    expect(result.tempMax, 20.0);
  });

  test('getByCategoria separa superiores de inferiores', () async {
    await repo.insert(prenda('Polera'));
    await repo.insert(prenda('Pantalon'));
    await repo.insert(prenda('Shorts'));

    final inferiores = await repo.getByCategoria(PrendaCategoria.inferior);

    expect(inferiores.length, 2);
  });

  test('CHECK temp_min <= temp_max rechaza rangos invertidos', () async {
    expect(
      () => repo.insert(prenda('Polera', min: 30, max: 10)),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'desactivar oculta la prenda de getAll pero getById la conserva',
    () async {
      final id = await repo.insert(prenda('Polera'));

      await repo.desactivar(id);

      expect(await repo.getAll(), isEmpty);
      expect(await repo.getById(id), isNotNull);
    },
  );
}
