import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';
import 'package:weathwear/domain/etl/etl_pipeline.dart';

const String etlTaskName = 'weathwear_etl_task';

// Se ejecuta en un isolate aparte, sin acceso al estado de main()
// Por eso arma sus propias dependencias en lugar de recibirlas.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != etlTaskName) return Future.value(true);

    final pipeline = EtlPipeline(
      ClimaApiClient(),
      ClimaTransformer(),
      ClimaRepository(dbHellper: SqliteHelper.instance),
    );

    final result = await pipeline.run();

    if (result.success) {
      debugPrint('ETL OK - duracion: ${result.duration.inMilliseconds}ms');
    } else {
      debugPrint(
        'ETL FALLO - ${result.error} (${result.duration.inMilliseconds})ms',
      );
    }

    //Registrar siempre true: si devuelve false, WorkManager reintenta agresivamente y puede saturar la bateria/red ante fallas persistentes de la API
    //Ya se maneja el error dentro de la pipeline, no hace falta que WorkManager reintente por su cuenta
    return Future.value(true);
  });
}

class EtlScheduler {
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  Future<void> shedulerPeriodic() async {
    await Workmanager().registerPeriodicTask(
      etlTaskName,
      etlTaskName,
      frequency: const Duration(hours: 1), //RF-01: extraccion periodica
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> cancelAll() => Workmanager().cancelAll();
}
