import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/ajustes.dart';
import 'package:weathwear/data/storage/ajustes_storage.dart';
import 'package:weathwear/domain/settings/ajustes_controller.dart';

// Fake: AjustesStorage real necesita path_provider (canal de plataforma)
class _FakeStorage implements AjustesStorage {
  Ajustes guardado = const Ajustes();
  @override
  Future<Ajustes> leer() async => guardado;
  @override
  Future<void> guardar(Ajustes ajustes) async => guardado = ajustes;
}

void main() {
  test('fromJson usa defaults ante claves ausentes o valores desconocidos', () {
    final a = Ajustes.fromJson({'tema': 'rosado', 'usarGps': 'si'});

    expect(a.tema, ThemeMode.system);
    expect(a.usarGps, true);
    expect(a.unidadViento, UnidadViento.kmh);
  });

  test('toJson -> fromJson conserva todos los valores', () {
    const original = Ajustes(
      tema: ThemeMode.dark,
      usarGps: false,
      formatoFecha: FormatoFecha.mesDiaAnio,
      vistaInicial: VistaInicial.hoy2,
      unidadTemperatura: UnidadTemperatura.fahrenheit,
      unidadViento: UnidadViento.mph,
    );

    final copia = Ajustes.fromJson(original.toJson());

    expect(copia.toJson(), original.toJson());
  });

  test('actualizar notifica a los oyentes y persiste', () async {
    final storage = _FakeStorage();
    final controller = AjustesController(storage: storage);
    var notificaciones = 0;
    controller.addListener(() => notificaciones++);

    await controller.actualizar(
      controller.ajustes.copyWith(tema: ThemeMode.dark),
    );

    expect(notificaciones, 1);
    expect(controller.ajustes.tema, ThemeMode.dark);
    expect(storage.guardado.tema, ThemeMode.dark);
  });
}
