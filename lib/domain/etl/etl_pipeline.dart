import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';
import 'package:weathwear/domain/etl/etl_result.dart';

//Orquesta extraccion -> transformacion -> carga (RF-01, RF-02, RF-03)
class EtlPipeline {
  final ClimaApiClient _apiClient;
  final ClimaTransformer _transformer;
  final ClimaRepository _repository;

  EtlPipeline(this._apiClient, this._transformer, this._repository);

  Future<EtlResult> run() async {
    final stopwatch = Stopwatch()..start();
    try {
      final raw = await _apiClient.fetchClimaActual();
      final clima = _transformer.transform(raw);
      await _repository.insert(clima);
      stopwatch.stop();
      return EtlResult.ok(stopwatch.elapsed);
    } on ClimaApiExeption catch (e) {
      stopwatch.stop();
      return EtlResult.failure(stopwatch.elapsed, e.toString());
    } finally {
      _apiClient.dispose();
    }
  }
}
