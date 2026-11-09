import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Archivo real (no en memoria): hay que cerrar y reabrir para que corra onUpgrade
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('weathwear_migracion');
    path = p.join(dir.path, 'test.db');
  });

  tearDown(() => dir.delete(recursive: true));

  // Mismos callbacks que producción. Las versiones 4-6 comparten el esquema
  // (v5 y v6 solo migran datos), así que onCreate sirve para sembrar una v4/v5.
  // onCreate ya incluye OutfitUso.corregido (v7): esos casos prueban además que
  // la migración v7 es idempotente.
  Future<Database> abrir(int version) => databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: SqliteHelper.onConfigure,
      onCreate: SqliteHelper.onCreate,
      onUpgrade: SqliteHelper.onUpgrade,
    ),
  );

  Future<int> prenda(Database db, String tipo) => db.insert('Prenda', {
    'tipo': tipo,
    'imagen_ruta': '/tmp/$tipo.jpg',
    'temp_min': 5,
    'temp_max': 20,
    'condicion_aplicable': 'soleado',
  });

  Future<int> outfit(Database db, List<int> idsPrenda) async {
    final id = await db.insert('Outfit', {
      'fecha_creacion': '2026-10-30T10:00:00',
    });
    for (final idPrenda in idsPrenda) {
      await db.insert('OutfitPrenda', {'id_outfit': id, 'id_prenda': idPrenda});
    }
    return id;
  }

  test('v4 -> actual: Poleron pasa a Chaqueta y se borran sus outfits', () async {
    var db = await abrir(4);
    final polera = await prenda(db, 'Polera');
    final poleron = await prenda(db, 'Poleron');
    final pantalon = await prenda(db, 'Pantalon');

    final valido = await outfit(db, [polera, pantalon]);
    final conPoleron = await outfit(db, [poleron, pantalon]);
    final idClima = await db.insert('Clima', {
      'fecha_hora': '2026-10-30T10:00:00',
      'temperatura': 10,
      'humedad': 50,
      'condicion': 'nublado',
    });
    await db.insert('OutfitUso', {
      'id_outfit': conPoleron,
      'id_clima': idClima,
      'fecha_uso': '2026-10-30T10:00:00',
    });
    await db.close();

    db = await abrir(SqliteHelper.dbVersion);

    final tipos = (await db.query(
      'Prenda',
      orderBy: 'id_prenda',
    )).map((r) => r['tipo'] as String).toList();
    expect(tipos, ['Polera', 'Chaqueta', 'Pantalon']);
    // Regresión del typo: todo tipo migrado debe ser reconocido por el dominio
    for (final t in tipos) {
      expect(() => PrendaCategoriaMapper.fromTipo(t), returnsNormally);
    }

    final outfits = await db.query('Outfit');
    expect(outfits.map((r) => r['id_outfit']), [valido]);
    expect(await db.query('OutfitUso'), isEmpty); // CASCADE
    expect(
      (await db.query('OutfitPrenda')).every((r) => r['id_outfit'] == valido),
      isTrue,
    );
    await db.close();
  });

  test('v5 -> v6: corrige el tipo Chaquetas del typo', () async {
    var db = await abrir(5);
    await prenda(db, 'Chaquetas');
    await db.close();

    db = await abrir(SqliteHelper.dbVersion);

    final fila = (await db.query('Prenda')).single;
    expect(fila['tipo'], 'Chaqueta');
    await db.close();
  });

  test('v6 -> v7: agrega OutfitUso.corregido sin perder usos', () async {
    // Esquema v6 real: OutfitUso sin la columna corregido
    var db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: SqliteHelper.onConfigure,
        onCreate: (db, _) async {
          await SqliteHelper.onCreate(db, 6);
          await db.execute('DROP TABLE OutfitUso');
          await db.execute('''
            CREATE TABLE OutfitUso (
              id_uso INTEGER PRIMARY KEY AUTOINCREMENT,
              id_outfit INTEGER NOT NULL, id_clima INTEGER NOT NULL,
              fecha_uso TEXT NOT NULL)
          ''');
        },
      ),
    );
    final polera = await prenda(db, 'Polera');
    final pantalon = await prenda(db, 'Pantalon');
    final idOutfit = await outfit(db, [polera, pantalon]);
    final idClima = await db.insert('Clima', {
      'fecha_hora': '2026-11-01T10:00:00',
      'temperatura': 12,
      'humedad': 60,
      'condicion': 'nublado',
    });
    await db.insert('OutfitUso', {
      'id_outfit': idOutfit,
      'id_clima': idClima,
      'fecha_uso': '2026-11-01T10:00:00',
    });
    await db.close();

    db = await abrir(SqliteHelper.dbVersion);

    final uso = (await db.query('OutfitUso')).single;
    expect(uso.containsKey('corregido'), isTrue);
    expect(uso['corregido'], isNull); // usos antiguos: sin dato
    await db.close();
  });

  test('instalación nueva: OutfitUso trae corregido', () async {
    final db = await abrir(SqliteHelper.dbVersion);
    final columnas = await db.rawQuery('PRAGMA table_info(OutfitUso)');
    expect(columnas.map((c) => c['name']), contains('corregido'));
    await db.close();
  });
}
