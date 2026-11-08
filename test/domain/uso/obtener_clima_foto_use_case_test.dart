import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/coordenadas.dart';
import 'package:weathwear/data/photo/foto_metadata_reader.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/domain/uso/obtener_clima_foto_use_case.dart';

// Lector falso: evita generar JPEG en estos tests (eso se prueba aparte)
class _FakeReader extends FotoMetadataReader {
  _FakeReader(this.meta);
  final FotoMetadata meta;
  @override
  Future<FotoMetadata> leer(String path) async => meta;
}

String _hourly() => jsonEncode({
  'hourly': {
    'time': ['2026-11-05T14:00', '2026-11-05T15:00'],
    'temperature_2m': [21.0, 22.0],
    'relative_humidity_2m': [40, 42],
    'weather_code': [0, 0],
    'apparent_temperature': [20.0, 21.0],
    'wind_speed_10m': [8.0, 9.0],
  },
});

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ClimaRepository climaRepo;
  late int llamadasApi;
  late Uri? ultimaUri;
  final ahora = DateTime(2026, 11, 8, 12);
  final fotoHora = DateTime(2026, 11, 5, 14, 10);

  ClimaApiClient apiFalsa() => ClimaApiClient(
    httpClient: MockClient((req) async {
      llamadasApi++;
      ultimaUri = req.url;
      return http.Response(_hourly(), 200);
    }),
  );

  ObtenerClimaFotoUseCase crear(
    FotoMetadata meta, {
    Coordenadas? guardada,
    ClimaApiClient Function()? api,
  }) => ObtenerClimaFotoUseCase(
    reader: _FakeReader(meta),
    climaRepo: climaRepo,
    ubicacionGuardada: () async => guardada,
    apiFactory: api ?? apiFalsa,
    now: () => ahora,
  );

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE Clima (
        id_clima INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL, temperatura REAL NOT NULL,
        humedad REAL NOT NULL, condicion TEXT NOT NULL,
        sensacion_termica REAL, viento_kmh REAL)
    ''');
    SqliteHelper.setTestDatabase(db);
    climaRepo = ClimaRepository();
    llamadasApi = 0;
    ultimaUri = null;
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  group('ObtenerClimaFotoUseCase (RF-11)', () {
    test('con GPS: consulta la API en esas coordenadas y persiste', () async {
      final r = await crear(
        FotoMetadata(
          fechaHora: fotoHora,
          fechaDesdeExif: true,
          coordenadas: const Coordenadas(latitud: -36.8, longitud: -73.05),
        ),
      )('foto.jpg');

      expect(llamadasApi, 1);
      expect(ultimaUri!.queryParameters['latitude'], '-36.8');
      expect(r.origenUbicacion, OrigenUbicacion.foto);
      expect(r.reutilizado, isFalse);
      expect(r.clima.idClima, isNotNull);
      expect(r.clima.temperatura, 21.0);
      expect((await climaRepo.getUltimo())!.idClima, r.clima.idClima);
    });

    test('sin GPS: usa la ubicación guardada', () async {
      final r = await crear(
        FotoMetadata(fechaHora: fotoHora, fechaDesdeExif: true),
        guardada: const Coordenadas(latitud: -33.0, longitud: -71.5),
      )('foto.jpg');

      expect(r.origenUbicacion, OrigenUbicacion.guardada);
      expect(ultimaUri!.queryParameters['latitude'], '-33.0');
    });

    test('sin GPS ni ubicación guardada: Santiago por defecto', () async {
      final r = await crear(
        FotoMetadata(fechaHora: fotoHora, fechaDesdeExif: true),
      )('foto.jpg');
      expect(r.origenUbicacion, OrigenUbicacion.porDefecto);
      expect(r.coordenadas.latitud, Coordenadas.santiago.latitud);
    });

    test('sin GPS: reutiliza el registro del ETL de esa hora', () async {
      final idEtl = await climaRepo.insert(
        ClimaModel(
          fechaHora: DateTime(2026, 11, 5, 14),
          temperatura: 19,
          humedad: 50,
          condicion: 'despejado',
        ),
      );

      final r = await crear(
        FotoMetadata(fechaHora: fotoHora, fechaDesdeExif: true),
      )('foto.jpg');

      expect(llamadasApi, 0);
      expect(r.reutilizado, isTrue);
      expect(r.clima.idClima, idEtl);
    });

    test('foto con fecha futura -> ClimaFotoException', () async {
      expect(
        () => crear(
          FotoMetadata(
            fechaHora: ahora.add(const Duration(days: 1)),
            fechaDesdeExif: true,
          ),
        )('foto.jpg'),
        throwsA(isA<ClimaFotoException>()),
      );
    });

    test('error de la API -> ClimaFotoException', () async {
      final uc = crear(
        FotoMetadata(fechaHora: fotoHora, fechaDesdeExif: true),
        api: () => ClimaApiClient(
          httpClient: MockClient((_) async => http.Response('x', 500)),
        ),
      );
      await expectLater(uc('foto.jpg'), throwsA(isA<ClimaFotoException>()));
    });
  });
}
