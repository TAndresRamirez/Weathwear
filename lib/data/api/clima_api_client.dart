import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/clima_raw_models.dart';
import 'clima_api_exception.dart';

//Responsable unicamente de la Extraccion (E de ETL):
//consulta Open-Meteo y devuelve el modelo crudo. No trasnforma ni persiste

class ClimaApiClient {
  final http.Client _httpClient;
  final Duration _timeout;

  ClimaApiClient({http.Client? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? http.Client(),
      _timeout = timeout ?? ApiConstants.requestTimeout;

  Future<ClimaRawModels> fetchClimaActual({
    double latitude = ApiConstants.defaultLatitude,
    double longitude = ApiConstants.defaultLongitude,
  }) async {
    final uri = Uri.parse(ApiConstants.baseUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m,weather_code',
        'timezone': ApiConstants.timezone,
      },
    );

    late final http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const ClimaApiTimeoutException();
    } on SocketException catch (e) {
      throw ClimaApiConnectionException(e.message);
    }

    if (response.statusCode != 200) {
      throw ClimaApiHttpException(response.statusCode);
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ClimaRawModels.fromJson(json);
    } on FormatException catch (e) {
      throw ClimaApiParseException(e.message);
    }
  }

  void dispose() => _httpClient.close();
}
