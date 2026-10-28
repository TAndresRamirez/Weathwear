import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/core/utils/formato_fecha.dart';
import 'package:weathwear/data/models/historial_entry.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/presentation/widgets/prenda_foto_tile.dart';
import 'package:weathwear/core/utils/formato_unidades.dart';
import 'package:weathwear/domain/settings/ajustes_controller.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({
    super.key,
    this.loader,
    this.intervaloRotacion = const Duration(seconds: 3),
  });

  /// Inyectables para tests. Si loader es null usa el repositorio real.
  final Future<List<HistorialEntry>> Function()? loader;
  final Duration intervaloRotacion;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Future<List<HistorialEntry>> _future;

  // Un solo temporizador para todas las tarjetas: true = se muestra la
  // prenda exterior (3ª) en lugar de superior + inferior.
  final _verExterior = ValueNotifier<bool>(false);
  Timer? _timer;

  // El historial guarda un outfit por día: 4 outfits = los últimos 4 días
  static const int _maxOutfits = 4;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _verExterior.dispose();
    super.dispose();
  }

  Future<List<HistorialEntry>> _load() async {
    final entries = widget.loader != null
        ? await widget.loader!()
        : await RecomendacionRepository().getHistorial(dias: _maxOutfits);
    if (mounted) _ajustarRotacion(entries.any((e) => e.prendas.length > 2));
    return entries;
  }

  // El timer solo corre si hay al menos un outfit de 3 prendas
  void _ajustarRotacion(bool necesaria) {
    if (!necesaria) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(
      widget.intervaloRotacion,
      (_) => _verExterior.value = !_verExterior.value,
    );
  }

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
            itemBuilder: (_, i) =>
                _OutfitCard(entry: entries[i], verExterior: _verExterior),
          );
        },
      ),
    );
  }
}

/// Un bloque por día: prendas a la izquierda, cuadro "Datos" a la derecha.
class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.entry, required this.verExterior});

  final HistorialEntry entry;
  final ValueListenable<bool> verExterior;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _PrendasSlots(prendas: entry.prendas, verExterior: verExterior),
            const SizedBox(width: 8),
            Expanded(child: _DatosBox(entry: entry)),
          ],
        ),
      ),
    );
  }
}

/// Dos casillas fijas. Con 3 prendas alterna: [superior, inferior] -> [exterior]
/// (la exterior ocupa la casilla 1 y la 2 queda vacía), siempre en el mismo lugar.
class _PrendasSlots extends StatelessWidget {
  const _PrendasSlots({required this.prendas, required this.verExterior});

  final List<PrendaModel> prendas;
  final ValueListenable<bool> verExterior;

  @override
  Widget build(BuildContext context) {
    if (prendas.length < 3) return _FilaPrendas(prendas: prendas);

    return ValueListenableBuilder<bool>(
      valueListenable: verExterior,
      builder: (_, exterior, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _FilaPrendas(
          key: ValueKey(exterior),
          prendas: exterior ? [prendas[2]] : prendas.take(2).toList(),
        ),
      ),
    );
  }
}

class _FilaPrendas extends StatelessWidget {
  const _FilaPrendas({super.key, required this.prendas});

  static const double _tile = 72;
  final List<PrendaModel> prendas;

  Widget _slot(int i) => SizedBox(
    width: _tile,
    child: i < prendas.length
        ? PrendaFotoTile(prenda: prendas[i], size: _tile, sobrePanel: true)
        : null,
  );

  @override
  Widget build(BuildContext context) {
    // Alto fijo: el cambio de prendas no mueve el resto de la tarjeta
    return SizedBox(
      height: 100,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_slot(0), const SizedBox(width: 8), _slot(1)],
      ),
    );
  }
}

/// Todos los datos del momento de la recomendación, salvo la afinidad.
class _DatosBox extends StatelessWidget {
  const _DatosBox({required this.entry});
  final HistorialEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clima = entry.clima;
    // Texto oscuro fijo: el cian es claro en ambos temas
    final cuerpo = text.bodySmall?.copyWith(color: Colors.black87);
    final titulo = text.titleSmall?.copyWith(color: Colors.black87);

    // Escucha los ajustes: el diálogo se cierra sobre esta pantalla ya montada
    return ListenableBuilder(
      listenable: AjustesController.instance,
      builder: (context, _) {
        final a = AjustesController.instance.ajustes;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.wColors.acento,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${etiquetaDia(entry.fechaGeneracion, formato: a.formatoFecha)} · '
                '${formatearHora(entry.fechaGeneracion)}',
                style: titulo,
              ),
              const SizedBox(height: 6),
              Text(
                '${formatearTemperatura(clima.temperatura, a.unidadTemperatura)}'
                ' · ${clima.condicion}',
                style: cuerpo,
              ),
              // Nullables: vacíos en filas anteriores a la migración v3
              if (clima.sensacionTermica != null)
                Text(
                  'Sensación ${formatearTemperatura(clima.sensacionTermica!, a.unidadTemperatura)}',
                  style: cuerpo,
                ),
              Text(
                'Humedad ${clima.humedad.toStringAsFixed(0)}%',
                style: cuerpo,
              ),
              if (clima.vientoKmh != null)
                Text(
                  'Viento ${formatearViento(clima.vientoKmh!, a.unidadViento)}',
                  style: cuerpo,
                ),
            ],
          ),
        );
      },
    );
  }
}
