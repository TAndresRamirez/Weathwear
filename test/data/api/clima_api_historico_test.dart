import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weathwear/core/constants/api_constants.dart';
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';

// Respuesta "hourly" mínima de Open-Meteo con 3 horas
String _hourly({List<num?> temps = const [10, 12, 14]}) => jsonEncode({
  'hourly': {
    'time': ['2026-11-05T13:00', '2026-11-05T14:00', '2026-11-05T15:00'],
    'temperature_2m': temps,
    'relative_humidity_2m': [50, 55, 60],
    'weather_code': [0, 1, 3],
    'apparent_temperature': [9.5, 11.5, 13.5],
    'wind_speed_10m': [5, 6, 7],
  },
});

void main() {
  final ahora = DateTime(2026, 11, 8, 12);

  group('ClimaApiClient.fetchClimaHistorico (RF-11)', () {
    test('elige la hora más cercana a la de la foto', () async {
      final client = ClimaApiClient(
        httpClient: MockClient((_) async => http.Response(_hourly(), 200)),
      );
      final raw = await client.fetchClimaHistorico(
        fechaHora: DateTime(2026, 11, 5, 14, 20),
        ahora: ahora,
      );
      expect(raw.timestamp, DateTime(2026, 11, 5, 14));
      expect(raw.temperature, 12);
      expect(raw.relativeHumidity, 55);
      expect(raw.weatherCode, 1);
      expect(raw.apparentTermperature, 11.5);
      expect(raw.windSpeed, 6);
    });

    test('salta horas con valores null', () async {
      final client = ClimaApiClient(
        httpClient: MockClient(
          (_) async => http.Response(_hourly(temps: [10, null, 14]), 200),
        ),
      );
      final raw = await client.fetchClimaHistorico(
        fechaHora: DateTime(2026, 11, 5, 14, 40),
        ahora: ahora,
      );
      expect(raw.timestamp, DateTime(2026, 11, 5, 15));
    });

    test('foto reciente: endpoint de pronóstico con el día pedido', () async {
      late Uri pedida;
      final client = ClimaApiClient(
        httpClient: MockClient((req) async {
          pedida = req.url;
          return http.Response(_hourly(), 200);
        }),
      );
      await client.fetchClimaHistorico(
        fechaHora: DateTime(2026, 11, 5, 14),
        latitude: -33.4,
        longitude: -70.6,
        ahora: ahora,
      );
      expect(pedida.toString(), startsWith(ApiConstants.baseUrl));
      expect(pedida.queryParameters['start_date'], '2026-11-05');
      expect(pedida.queryParameters['end_date'], '2026-11-05');
      expect(pedida.queryParameters['hourly'], ApiConstants.hourlyParams);
      expect(pedida.queryParameters['latitude'], '-33.4');
    });

    test('foto antigua: endpoint de archivo histórico', () async {
      late Uri pedida;
      final client = ClimaApiClient(
        httpClient: MockClient((req) async {
          pedida = req.url;
          return http.Response(_hourly(), 200);
        }),
      );
      await client.fetchClimaHistorico(
        fechaHora: DateTime(2026, 1, 10, 14),
        ahora: ahora,
      );
      expect(pedida.toString(), startsWith(ApiConstants.archiveUrl));
      expect(pedida.queryParameters['start_date'], '2026-01-10');
    });

    test('sin bloque hourly -> ClimaApiParseException', () async {
      final client = ClimaApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(
        () => client.fetchClimaHistorico(
          fechaHora: DateTime(2026, 11, 5),
          ahora: ahora,
        ),
        throwsA(isA<ClimaApiParseException>()),
      );
    });

    test('todas las horas null -> ClimaApiParseException', () async {
      final client = ClimaApiClient(
        httpClient: MockClient(
          (_) async => http.Response(_hourly(temps: [null, null, null]), 200),
        ),
      );
      expect(
        () => client.fetchClimaHistorico(
          fechaHora: DateTime(2026, 11, 5, 14),
          ahora: ahora,
        ),
        throwsA(isA<ClimaApiParseException>()),
      );
    });

    test('error HTTP -> ClimaApiHttpException', () async {
      final client = ClimaApiClient(
        httpClient: MockClient((_) async => http.Response('error', 400)),
      );
      expect(
        () => client.fetchClimaHistorico(
          fechaHora: DateTime(2026, 11, 5, 14),
          ahora: ahora,
        ),
        throwsA(isA<ClimaApiHttpException>()),
      );
    });
  });
}
