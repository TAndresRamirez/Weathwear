import 'package:weathwear/data/models/clima_raw_models.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/domain/etl/weathwear_code_mapper.dart';

//Transforma la respuesta cruda de la Api al modelo persistible (RF-02)
class ClimaTransformer {
  ClimaModel transform(ClimaRawModels raw) {
    return ClimaModel(
      fechaHora: raw.timestamp,
      temperatura: raw.temperature,
      humedad: raw.relativeHumidity,
      condicion: WeathwearCodeMapper.toCondicion(raw.weatherCode),
    );
  }
}
