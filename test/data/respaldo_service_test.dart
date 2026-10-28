import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/storage/respaldo_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late Database db;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('weathwear_respaldo_test');
    db = await databaseFactory.openDatabase(p.join(tmp.path, 'origen.db'));
    await db.execute('CREATE TABLE Clima (id INTEGER PRIMARY KEY, temp REAL)');
    await db.insert('Clima', {'temp': 21.4});
    SqliteHelper.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
    await tmp.delete(recursive: true);
  });

  RespaldoService servicio(DateTime ahora) =>
      RespaldoService(carpetaTemporal: () async => tmp, now: () => ahora);

  test('la copia es una BD válida con los mismos datos', () async {
    final copia = await servicio(DateTime(2026, 10, 27, 9, 5)).crearCopia();

    expect(p.basename(copia.path), 'weathwear_respaldo_20261027_0905.db');

    final bd = await databaseFactory.openDatabase(copia.path);
    final filas = await bd.query('Clima');
    await bd.close();
    expect(filas.single['temp'], 21.4);
  });

  test('solo se conserva el último respaldo', () async {
    await servicio(DateTime(2026, 10, 27, 9, 5)).crearCopia();
    final segunda = await servicio(DateTime(2026, 10, 27, 18, 30)).crearCopia();

    final archivos = segunda.parent.listSync();
    expect(archivos.length, 1);
    expect(p.basename(archivos.single.path), contains('20261027_1830'));
  });
}
