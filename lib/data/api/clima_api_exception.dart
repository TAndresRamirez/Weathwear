//Exepciones especificas del cliente climatico
//Permiten que capas superiores (sheduler, UI) reaccionen distinto segun el tipo de fallo

sealed class ClimaApiExeption implements Exception {
  final String message;
  const ClimaApiExeption(this.message);

  @override
  String toString() => message;
}

class ClimaApiTimeoutException extends ClimaApiExeption {
  const ClimaApiTimeoutException()
    : super('Tiempo de espera agotado al consultar la API climatica');
}

class ClimaApiConnectionException extends ClimaApiExeption {
  const ClimaApiConnectionException(String detail)
    : super('Error de conexion con la Api climatica: $detail');
}

class ClimaApiHttpException extends ClimaApiExeption {
  final int statusCode;
  const ClimaApiHttpException(this.statusCode)
    : super('La Api climatica respondio con codigo $statusCode');
}

class ClimaApiParseException extends ClimaApiExeption {
  const ClimaApiParseException(String detail)
    : super('Error al procesar la respuesta de la Api climatica $detail');
}
