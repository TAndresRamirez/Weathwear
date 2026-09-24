import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';

void main() {
  group('ClimaApiClient.fetchClimaActual', () {
    test('TP-01: retorna ClimaRawModel cuando la Api responde 200', () async {
      final mockClient = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'current': {
              'time': '2026-09-23T15:00',
              'temperature_2m': 18.5,
              'relative_humidity_2m': 60,
              'weather_code': 1,
            },
          }),
          200,
        ),
      );
      final apiClient = ClimaApiClient(httpClient: mockClient);
      final result = await apiClient.fetchClimaActual();

      expect(result.temperature, 18.5);
      expect(result.relativeHumidity, 60.0);
      expect(result.weatherCode, 1);
    });

    test(
      'TP-02: lanza ClimaApiHttpExeption si la Api responde error',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response('Server error', 500),
        );
        final apiClient = ClimaApiClient(httpClient: mockClient);

        expect(
          () => apiClient.fetchClimaActual(),
          throwsA(isA<ClimaApiHttpException>()),
        );
      },
    );

    test(
      'TP-02: lanza ClimaApiTimeoutException si la Api no responde a tiempo',
      () async {
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response('{}', 200);
        });
        final apiClient = ClimaApiClient(
          httpClient: mockClient,
          timeout: const Duration(milliseconds: 10),
        );

        expect(
          () => apiClient.fetchClimaActual(),
          throwsA(isA<ClimaApiTimeoutException>()),
        );
      },
    );

    test(
      'lanza ClimaApiParseException si la respuesta viene malformada',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response('{"foo": "bar"}', 200),
        );
        final apiClient = ClimaApiClient(httpClient: mockClient);

        expect(
          () => apiClient.fetchClimaActual(),
          throwsA(isA<ClimaApiParseException>()),
        );
      },
    );
  });
}
