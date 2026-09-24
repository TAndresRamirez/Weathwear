//Registro de una ejecucion del pipeline, para logging
class EtlResult {
  final bool success;
  final Duration duration;
  final String? error;

  const EtlResult.ok(this.duration) : success = true, error = null;
  const EtlResult.failure(this.duration, this.error) : success = false;
}
