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
  }) {
    final uri = Uri.parse(ApiConstants.baseUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': ApiConstants.currentParams,
        'timezone': ApiConstants.timezone,
      },
    );
    return _get(uri, ClimaRawModels.fromJson);
  }

  /// Clima de un momento pasado (RF-11): pide las horas de ese día y se queda
  /// con la más cercana a [fechaHora].
  /// Hasta [ApiConstants.diasPasadosForecast] días atrás usa el endpoint de
  /// pronóstico (incluye las últimas horas); más atrás, el archivo histórico.
  Future<ClimaRawModels> fetchClimaHistorico({
    required DateTime fechaHora,
    double latitude = ApiConstants.defaultLatitude,
    double longitude = ApiConstants.defaultLongitude,
    DateTime? ahora, // inyectable en tests
  }) {
    final antiguedad = (ahora ?? DateTime.now()).difference(fechaHora);
    final url = antiguedad.inDays > ApiConstants.diasPasadosForecast
        ? ApiConstants.archiveUrl
        : ApiConstants.baseUrl;
    final dia = _fechaIso(fechaHora);

    final uri = Uri.parse(url).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'hourly': ApiConstants.hourlyParams,
        // La hora EXIF es la hora local donde se sacó la foto: "auto" hace que
        // la API responda en la zona horaria de esas coordenadas.
        'timezone': 'auto',
        'start_date': dia,
        'end_date': dia,
      },
    );
    return _get(uri, (json) => ClimaRawModels.fromHourlyJson(json, fechaHora));
  }

  // GET + manejo de errores común a ambos endpoints
  Future<T> _get<T>(Uri uri, T Function(Map<String, dynamic>) parse) async {
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
      return parse(json);
    } on FormatException catch (e) {
      throw ClimaApiParseException(e.message);
    } on TypeError catch (e) {
      // Un campo con tipo inseperado lanza TypeError, no FormatException
      throw ClimaApiParseException(e.toString());
    }
  }

  // yyyy-MM-dd, formato que esperan start_date/end_date
  static String _fechaIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void dispose() => _httpClient.close();
}
