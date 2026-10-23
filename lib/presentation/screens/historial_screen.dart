import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/core/utils/formato_fecha.dart';
import 'package:weathwear/data/models/historial_entry.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, this.loader});

  /// Inyectable para tests. Si es null usa el repositorio real.
  final Future<List<HistorialEntry>> Function()? loader;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Future<List<HistorialEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<HistorialEntry>> _load() => widget.loader != null
      ? widget.loader!()
      : RecomendacionRepository().getHistorial();

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<HistorialEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <HistorialEntry>[];
          // ListView también en el caso vacío para que funcione el pull-to-refresh
          if (snap.hasError || entries.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Text(
                    snap.hasError
                        ? 'No se pudo cargar el historial.'
                        : 'Aún no hay recomendaciones en tu historial.',
                    key: Key(
                      snap.hasError ? 'historial_error' : 'historial_vacio',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (_, i) => _DiaCard(entry: entries[i]),
          );
        },
      ),
    );
  }
}

/// Un bloque por día: la última recomendación generada ese día.
class _DiaCard extends StatelessWidget {
  const _DiaCard({required this.entry});
  final HistorialEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clima = entry.clima;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiquetaDia(entry.fechaGeneracion), style: text.titleLarge),
            Text(
              'Última recomendación: ${formatearHora(entry.fechaGeneracion)}',
              style: text.labelMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${clima.temperatura.toStringAsFixed(1)}°C · ${clima.condicion} · '
              '${clima.humedad.toStringAsFixed(0)}%',
              style: text.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [for (final p in entry.prendas) _PrendaChip(prenda: p)],
            ),
            const SizedBox(height: 8),
            Text(
              'Afinidad: ${(entry.similitud * 100).round()}%',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrendaChip extends StatelessWidget {
  const _PrendaChip({required this.prenda});
  final PrendaModel prenda;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(prenda.imagenRuta),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            // Si la foto se borró, no rompe la tarjeta
            errorBuilder: (_, _, _) => const SizedBox(
              width: 64,
              height: 64,
              child: Icon(Icons.checkroom_outlined),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(prenda.tipo, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
