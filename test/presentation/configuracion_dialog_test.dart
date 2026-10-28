import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/ajustes.dart';
import 'package:weathwear/data/storage/ajustes_storage.dart';
import 'package:weathwear/data/storage/respaldo_service.dart';
import 'package:weathwear/domain/settings/ajustes_controller.dart';
import 'package:weathwear/presentation/widgets/configuracion_dialog.dart';

// Fake: el storage real necesita path_provider (canal de plataforma)
class _FakeStorage implements AjustesStorage {
  @override
  Future<Ajustes> leer() async => const Ajustes();
  @override
  Future<void> guardar(Ajustes ajustes) async {}
}

// Fake: evita tocar la BD real y el sistema de archivos
class _FakeRespaldo extends RespaldoService {
  _FakeRespaldo({this.falla = false});
  final bool falla;

  @override
  Future<File> crearCopia() async {
    if (falla) throw Exception('sin espacio');
    return File('/tmp/respaldo.db');
  }

  @override
  Future<String> rutaBd() async => '/data/weathwear.db';
}

void main() {
  late AjustesController controller;

  setUp(() => controller = AjustesController(storage: _FakeStorage()));

  // respaldo y compartir son PARÁMETROS de wrap (entre llaves), no variables
  Widget wrap({
    RespaldoService? respaldo,
    Future<void> Function(String path)? compartir,
  }) => MaterialApp(
    home: Scaffold(
      body: ConfiguracionDialog(
        controller: controller,
        respaldo: respaldo ?? _FakeRespaldo(),
        compartir: compartir ?? (_) async {},
      ),
    ),
  );

  testWidgets('cambiar tema y GPS actualiza los ajustes', (t) async {
    await t.pumpWidget(wrap());

    await t.tap(find.text('Oscuro'));
    await t.pump();
    expect(controller.ajustes.tema, ThemeMode.dark);

    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    expect(controller.ajustes.usarGps, false);
  });

  testWidgets('personalización actualiza unidades', (t) async {
    await t.pumpWidget(wrap());

    await t.ensureVisible(find.text('°F'));
    await t.tap(find.text('°F'));
    await t.pump();
    expect(controller.ajustes.unidadTemperatura, UnidadTemperatura.fahrenheit);

    await t.ensureVisible(find.text('mph'));
    await t.tap(find.text('mph'));
    await t.pump();
    expect(controller.ajustes.unidadViento, UnidadViento.mph);
  });

  testWidgets('respaldar comparte el archivo generado', (t) async {
    final compartidos = <String>[];
    await t.pumpWidget(wrap(compartir: (path) async => compartidos.add(path)));

    await t.ensureVisible(find.text('Respaldar datos'));
    await t.tap(find.text('Respaldar datos'));
    await t.pumpAndSettle();

    expect(compartidos, ['/tmp/respaldo.db']);
  });

  testWidgets('si el respaldo falla muestra el error en el diálogo', (t) async {
    await t.pumpWidget(wrap(respaldo: _FakeRespaldo(falla: true)));

    await t.ensureVisible(find.text('Respaldar datos'));
    await t.tap(find.text('Respaldar datos'));
    await t.pumpAndSettle();

    expect(find.text('No se pudo crear el respaldo'), findsOneWidget);
  });

  testWidgets('muestra la ubicación de la BD', (t) async {
    await t.pumpWidget(wrap());

    await t.ensureVisible(find.text('Ubicación de los datos'));
    await t.tap(find.text('Ubicación de los datos'));
    await t.pumpAndSettle();

    expect(find.text('/data/weathwear.db'), findsOneWidget);
  });

  testWidgets('idioma muestra el aviso "en proceso"', (t) async {
    await t.pumpWidget(wrap());

    await t.ensureVisible(find.text('Idioma'));
    await t.tap(find.text('Idioma'));
    await t.pumpAndSettle();

    expect(find.text('Función en proceso.'), findsOneWidget);
  });
}
