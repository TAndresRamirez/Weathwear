import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_raw_models.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';
import 'package:weathwear/domain/etl/etl_pipeline.dart';

// Fake del cliente de API: evita golpear Open-Meteo real en el test TP-01/TP-09
// Prueban el pipeline completo, no la disponibilidad de la API externa
class _FakeClimaApiClient implements ClimaApiClient {
  final Future<ClimaRawModels> Function() onFetch;
  _FakeClimaApiClient(this.onFetch);

  @override
  Future<ClimaRawModels> fetchClimaActual({
    double latitude = 0,
    double longitude = 0,
  }) => onFetch();

  @override
  void dispose() {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE Clima (
        id_clima INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL,
        temperatura REAL NOT NULL,
        humedad REAL NOT NULL,
        condicion TEXT NOT NULL
      )
    ''');
    SqliteHelper.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  test('TP-01/TP-09: pipeline completo inserta el registro en Clima', () async {
    final fakeClient = _FakeClimaApiClient(
      () async => ClimaRawModels(
        timestamp: DateTime(2026, 9, 24, 15),
        temperature: 21.4,
        relativeHumidity: 36.0,
        weatherCode: 0,
      ),
    );

    final pipeline = EtlPipeline(
      fakeClient,
      ClimaTransformer(),
      ClimaRepository(dbHellper: SqliteHelper.instance),
    );

    final result = await pipeline.run();

    expect(result.success, true);
    final rows = await db.query('Clima');
    expect(rows.length, 1);
    expect(rows.first['condicion'], 'soleado');
  });

  test(
    'TP-02: error de API no interrumpe el servicio y queda registrado',
    () async {
      final fakeClient = _FakeClimaApiClient(
        () async => throw const ClimaApiTimeoutException(),
      );

      final pipeline = EtlPipeline(
        fakeClient,
        ClimaTransformer(),
        ClimaRepository(dbHellper: SqliteHelper.instance),
      );

      final result = await pipeline.run();

      expect(result.success, false);
      expect(result.error, isNotNull);
      final rows = await db.query('Clima');
      expect(rows, isEmpty);
    },
  );
}
