import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';
import 'package:weathwear/domain/outfits/usar_outfit_use_case.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late OutfitRepository repo;
  late PrendaRepository prendaRepo;
  late ClimaRepository climaRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE Clima (
        id_clima INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL, temperatura REAL NOT NULL,
        humedad REAL NOT NULL, condicion TEXT NOT NULL,
        sensacion_termica REAL, viento_kmh REAL)
    ''');
    await db.execute('''
      CREATE TABLE Prenda (
        id_prenda INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL, imagen_ruta TEXT NOT NULL,
        temp_min REAL NOT NULL, temp_max REAL NOT NULL,
        condicion_aplicable TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1)
    ''');
    await SqliteHelper.crearTablasOutfit(db);
    SqliteHelper.setTestDatabase(db);
    repo = OutfitRepository();
    prendaRepo = PrendaRepository();
    climaRepo = ClimaRepository();
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  Future<PrendaModel> prenda(String tipo) async {
    final id = await prendaRepo.insert(
      PrendaModel(
        tipo: tipo,
        imagenRuta: '/tmp/$tipo.jpg',
        tempMin: 5,
        tempMax: 25,
        condicionAplicable: 'soleado',
      ),
    );
    return (await prendaRepo.getById(id))!;
  }

  Future<int> clima(double temp, DateTime fecha) => climaRepo.insert(
    ClimaModel(
      fechaHora: fecha,
      temperatura: temp,
      humedad: 50,
      condicion: 'soleado',
    ),
  );

  group('OutfitRepository', () {
    test(
      'getAll devuelve las prendas ordenadas: superior, inferior, exterior',
      () async {
        final pantalon = await prenda('Pantalon');
        final chaqueta = await prenda('Chaqueta');
        final polera = await prenda('Polera');

        await repo.insert(
          idsPrenda: [pantalon.idPrenda!, chaqueta.idPrenda!, polera.idPrenda!],
        );

        final outfit = (await repo.getAll()).single;
        expect(outfit.prendas.map((p) => p.tipo), [
          'Polera',
          'Pantalon',
          'Chaqueta',
        ]);
        expect(outfit.exterior?.tipo, 'Chaqueta');
        expect(outfit.vecesUsado, 0);
        expect(outfit.tempPromedioUso, isNull);
      },
    );

    test(
      'buscarIdPorPrendas exige el mismo conjunto, sin importar el orden',
      () async {
        final a = await prenda('Polera');
        final b = await prenda('Pantalon');
        final c = await prenda('Chaqueta');
        final id = await repo.insert(idsPrenda: [a.idPrenda!, b.idPrenda!]);

        expect(await repo.buscarIdPorPrendas({b.idPrenda!, a.idPrenda!}), id);
        // subconjunto y superconjunto no cuentan como el mismo outfit
        expect(await repo.buscarIdPorPrendas({a.idPrenda!}), isNull);
        expect(
          await repo.buscarIdPorPrendas({
            a.idPrenda!,
            b.idPrenda!,
            c.idPrenda!,
          }),
          isNull,
        );
      },
    );

    test('registrarUso: un uso por día y estadísticas calculadas', () async {
      final a = await prenda('Polera');
      final b = await prenda('Pantalon');
      final id = await repo.insert(idsPrenda: [a.idPrenda!, b.idPrenda!]);
      final dia1 = DateTime(2026, 10, 26, 9);
      final dia2 = DateTime(2026, 10, 27, 9);
      final c1 = await clima(10, dia1);
      final c2 = await clima(20, dia2);

      expect(
        await repo.registrarUso(idOutfit: id, idClima: c1, fecha: dia1),
        true,
      );
      expect(
        await repo.registrarUso(
          idOutfit: id,
          idClima: c1,
          fecha: DateTime(2026, 10, 26, 18),
        ),
        false, // mismo día
      );
      expect(
        await repo.registrarUso(idOutfit: id, idClima: c2, fecha: dia2),
        true,
      );

      final outfit = (await repo.getAll()).single;
      expect(outfit.vecesUsado, 2);
      expect(outfit.tempPromedioUso, 15.0);
      expect(outfit.ultimoUso, dia2);
    });

    test('eliminar borra también sus prendas asociadas y sus usos', () async {
      final a = await prenda('Polera');
      final b = await prenda('Pantalon');
      final id = await repo.insert(idsPrenda: [a.idPrenda!, b.idPrenda!]);
      final fecha = DateTime(2026, 10, 26, 9);
      await repo.registrarUso(
        idOutfit: id,
        idClima: await clima(12, fecha),
        fecha: fecha,
      );

      await repo.eliminar(id);

      expect(await db.query('Outfit'), isEmpty);
      expect(await db.query('OutfitPrenda'), isEmpty);
      expect(await db.query('OutfitUso'), isEmpty);
    });

    test('oculta el outfit si alguna de sus prendas fue desactivada', () async {
      final a = await prenda('Polera');
      final b = await prenda('Pantalon');
      await repo.insert(idsPrenda: [a.idPrenda!, b.idPrenda!]);

      await prendaRepo.desactivar(a.idPrenda!);

      expect(await repo.getAll(), isEmpty);
    });
  });

  group('GuardarOutfitUseCase', () {
    late GuardarOutfitUseCase guardar;
    setUp(() => guardar = GuardarOutfitUseCase(repo));

    test('guarda un outfit válido y rechaza el duplicado', () async {
      final polera = await prenda('Polera');
      final pantalon = await prenda('Pantalon');

      expect(await guardar([polera, pantalon]), isPositive);
      await expectLater(
        guardar([pantalon, polera]),
        throwsA(isA<OutfitException>()),
      );
    });

    test('exige una superior y una inferior', () async {
      final polera = await prenda('Polera');
      final poleron = await prenda('Poleron');

      await expectLater(guardar([polera]), throwsA(isA<OutfitException>()));
      await expectLater(
        guardar([polera, poleron]),
        throwsA(isA<OutfitException>()),
      );
    });

    test('rechaza prendas sin id', () async {
      const sinId = PrendaModel(
        tipo: 'Polera',
        imagenRuta: '/x.jpg',
        tempMin: 5,
        tempMax: 25,
        condicionAplicable: 'soleado',
      );
      await expectLater(guardar([sinId]), throwsA(isA<OutfitException>()));
    });
  });

  group('UsarOutfitUseCase', () {
    test('sin clima lanza OutfitException', () async {
      final a = await prenda('Polera');
      final b = await prenda('Pantalon');
      final id = await repo.insert(idsPrenda: [a.idPrenda!, b.idPrenda!]);

      await expectLater(
        UsarOutfitUseCase(repo, climaRepo)(id),
        throwsA(isA<OutfitException>()),
      );
    });

    test(
      'registra el uso con el último clima y no lo duplica el mismo día',
      () async {
        final a = await prenda('Polera');
        final b = await prenda('Pantalon');
        final id = await repo.insert(idsPrenda: [a.idPrenda!, b.idPrenda!]);
        final ahora = DateTime(2026, 10, 26, 15);
        await clima(18, ahora);
        final usar = UsarOutfitUseCase(repo, climaRepo, now: () => ahora);

        expect(await usar(id), true);
        expect(await usar(id), false);
        expect((await repo.getAll()).single.vecesUsado, 1);
      },
    );
  });
}
