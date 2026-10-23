import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/location/ubicacion_service.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';
import 'package:weathwear/domain/etl/etl_pipeline.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.loader, this.recomendar});

  /// Inyectables para tests. Si son null se usa el flujo real.
  final Future<ClimaModel?> Function({bool force})? loader;
  final Future<RecomendacionResultado> Function()? recomendar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Lo que pinta la pantalla en un momento dado
class _HomeData {
  const _HomeData({this.clima, this.recomendacion, this.mensajeReco});
  final ClimaModel? clima;
  final RecomendacionResultado? recomendacion;
  final String? mensajeReco; // por qué no hay recomendación
}

class _HomeScreenState extends State<HomeScreen> {
  final _climaRepo = ClimaRepository();
  final _ubicacion = UbicacionService();
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<ClimaModel?> _loadClima({bool force = false}) => widget.loader != null
      ? widget.loader!(force: force)
      : _loadClimaDefault(force: force);

  /// Lee el último clima; si falta o tiene >1 h, corre el ETL.
  Future<ClimaModel?> _loadClimaDefault({bool force = false}) async {
    var clima = await _climaRepo.getUltimo();
    final stale =
        clima == null ||
        DateTime.now().difference(clima.fechaHora) > const Duration(hours: 1);
    if (force || stale) {
      // EtlPipeline cierra su ApiClient en run(): uno nuevo por ejecución.
      // En primer plano se pide GPS (y se cachea para el ETL en background).
      await EtlPipeline(
        ClimaApiClient(),
        ClimaTransformer(),
        _climaRepo,
        coordenadas: _ubicacion.obtener,
      ).run();
      clima = await _climaRepo.getUltimo();
    }
    return clima;
  }

  Future<RecomendacionResultado> _recomendar() => widget.recomendar != null
      ? widget.recomendar!()
      : GenerarRecomendacionUseCase(
          _climaRepo,
          PrendaRepository(),
          RecomendacionRepository(),
        )();

  Future<_HomeData> _loadAll({bool force = false}) async {
    final clima = await _loadClima(force: force);
    if (clima == null) return const _HomeData();
    try {
      return _HomeData(clima: clima, recomendacion: await _recomendar());
    } on RecommendationException catch (e) {
      return _HomeData(clima: clima, mensajeReco: e.message);
    } catch (_) {
      return _HomeData(
        clima: clima,
        mensajeReco: 'No se pudo generar la recomendación',
      );
    }
  }

  Future<void> _refresh() async {
    final next = _loadAll(force: true);
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          // ListView (no Column) para que el pull-to-refresh siempre funcione
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (snap.hasError || data?.clima == null)
                const _EmptyState()
              else ...[
                _ClimaCard(clima: data!.clima!),
                const SizedBox(height: 16),
                _RecomendacionCard(
                  resultado: data.recomendacion,
                  mensaje: data.mensajeReco,
                ),
              ],
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
            Text(
              clima.condicion,
              key: const Key('clima_condicion'),
              style: text.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Humedad: ${clima.humedad.toStringAsFixed(0)}%'),
            // Nullable: filas anteriores a la migración v3 no tienen estos datos
            if (clima.sensacionTermica != null)
              Text(
                'Sensación térmica: ${clima.sensacionTermica!.toStringAsFixed(1)}°C',
              ),
            if (clima.vientoKmh != null)
              Text('Viento: ${clima.vientoKmh!.toStringAsFixed(0)} km/h'),
          ],
        ),
      ),
    );
  }
}

class _RecomendacionCard extends StatelessWidget {
  const _RecomendacionCard({this.resultado, this.mensaje});
  final RecomendacionResultado? resultado;
  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = resultado;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: r == null
            ? Text(
                mensaje ?? 'Sin recomendación disponible',
                textAlign: TextAlign.center,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hoy te recomiendo', style: text.titleMedium),
                  if (r.climaDesactualizado)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'El clima tiene más de 3 horas; desliza para actualizar.',
                        style: text.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (final p in r.outfit.prendas) _PrendaTile(prenda: p),
                  const SizedBox(height: 8),
                  Text(
                    'Afinidad: ${(r.outfit.similitud * 100).round()}%',
                    style: text.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrendaTile extends StatelessWidget {
  const _PrendaTile({required this.prenda});
  final PrendaModel prenda;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(prenda.imagenRuta),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          // Si el archivo se borró, no rompe la lista
          errorBuilder: (_, _, _) => const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.checkroom_outlined),
          ),
        ),
      ),
      title: Text(prenda.tipo),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 80),
    child: Text(
      'Sin datos climáticos. Revisa tu conexión y desliza para reintentar.',
      textAlign: TextAlign.center,
    ),
  );
}
