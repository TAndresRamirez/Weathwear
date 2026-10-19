import 'dart:async';

import 'package:flutter/material.dart';
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';
import 'package:weathwear/domain/etl/etl_pipeline.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.loader});

  // Permite inyectar la carga de datos (tests). Si es null, usa el flujo real
  final Future<ClimaModel?> Function({bool force})? loader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ClimaRepository();
  late Future<ClimaModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Lee el ultimo clima: si no hay o esta desactualizado (>1 h),corre el ETL
  Future<ClimaModel?> _load({bool force = false}) => widget.loader != null
      ? widget.loader!(force: force)
      : _loadDefault(force: force);

  Future<ClimaModel?> _loadDefault({bool force = false}) async {
    var clima = await _repository.getUltimo();
    final stale =
        clima == null ||
        DateTime.now().difference(clima.fechaHora) > const Duration(hours: 1);

    if (force || stale) {
      // EtlPipeline cierra su ApiClient en run(): se crea uno nuevo por ejecucion
      await EtlPipeline(
        ClimaApiClient(),
        ClimaTransformer(),
        _repository,
      ).run();
      clima = await _repository.getUltimo();
    }
    return clima;
  }

  Future<void> _refresh() async {
    final next = _load(force: true);
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ClimaModel?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final clima = snap.data;
          // ListView (no Column) para qeu el pull-to-refresh funcione siempre.
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (snap.hasError || clima == null)
                const _EmptyState()
              else
                _ClimaCard(clima: clima),
            ],
          );
        },
      ),
    );
  }
}

class _ClimaCard extends StatelessWidget {
  const _ClimaCard({required this.clima});
  final ClimaModel clima;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '${clima.temperatura.toStringAsFixed(1)}°C',
              style: text.displayMedium,
            ),
            const SizedBox(height: 8),
            // Key estable: el test no depende del copy ni de mayúsculas.
            Text(
              clima.condicion,
              key: const Key('clima_condicion'),
              style: text.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Humedad: ${clima.humedad.toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 80),
    child: Text(
      'Sin datos climaticos. Revisa tu conexion y desliza para reinintentar.',
      textAlign: TextAlign.center,
    ),
  );
}
