//Exepciones especificas del cliente climatico
//Permiten que capas superiores (sheduler, UI) reaccionen distinto segun el tipo de fallo

sealed class ClimaApiException implements Exception {
  final String message;
  const ClimaApiException(this.message);

  @override
  String toString() => message;
}

class ClimaApiTimeoutException extends ClimaApiException {
  const ClimaApiTimeoutException()
    : super('Tiempo de espera agotado al consultar la API climatica');
}

class ClimaApiConnectionException extends ClimaApiException {
  const ClimaApiConnectionException(String detail)
    : super('Error de conexion con la Api climatica: $detail');
}

class ClimaApiHttpException extends ClimaApiException {
  final int statusCode;
  const ClimaApiHttpException(this.statusCode)
    : super('La Api climatica respondio con codigo $statusCode');
}

class ClimaApiParseException extends ClimaApiException {
  const ClimaApiParseException(String detail)
    : super('Error al procesar la respuesta de la Api climatica $detail');
}
