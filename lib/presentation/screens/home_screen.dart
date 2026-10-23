import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/location/ubicacion_service.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/repositories/recomendacion_repository.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';
import 'package:weathwear/domain/etl/etl_pipeline.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';
import 'package:weathwear/presentation/widgets/clima_panel.dart';
import 'package:weathwear/presentation/widgets/recomendacion_panel.dart';

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
  static const double _alturaHandle = 32; // px visibles con el panel cerrado
  static const double _fraccionMax = 0.62; // alto máximo del panel abierto

  final _climaRepo = ClimaRepository();
  final _ubicacion = UbicacionService();
  final _sheet = DraggableScrollableController();
  late Future<_HomeData> _future;

  bool _expandido = false;
  double _fraccionMin = 0.05; // se recalcula en build según el alto disponible

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _sheet.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  // Solo reconstruye cuando cambia de estado (no en cada frame del arrastre)
  void _onSheetChanged() {
    if (!_sheet.isAttached) return;
    final abierto = _sheet.size > (_fraccionMin + _fraccionMax) / 2;
    if (abierto != _expandido) setState(() => _expandido = abierto);
  }

  // Tocar el handle abre/cierra el panel (alternativa al arrastre)
  void _alternarPanel() => _sheet.animateTo(
    _expandido ? _fraccionMin : _fraccionMax,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  // TODO(etapa 4): persistir el outfit (tablas Outfit y OutfitPrenda, BD v4)
  void _guardarComoOutfit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardar outfits llega en la Etapa 4')),
    );
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
    // El panel se reconstruye cerrado, así que el estado vuelve a "no expandido"
    setState(() {
      _expandido = false;
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        final clima = data?.clima;

        // ListView (no Column) para que el pull-to-refresh siempre funcione
        if (snap.hasError || clima == null) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [_EmptyState()],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, box) {
            _fraccionMin = _alturaHandle / box.maxHeight;
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Espacio inferior para que el handle no tape contenido
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      _alturaHandle + 16,
                    ),
                    children: [ClimaPanel(clima: clima, compacto: _expandido)],
                  ),
                ),
                DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: _fraccionMin,
                  minChildSize: _fraccionMin,
                  maxChildSize: _fraccionMax,
                  snap: true,
                  builder: (context, scrollController) => _PanelDeslizable(
                    scrollController: scrollController,
                    expandido: _expandido,
                    onToggle: _alternarPanel,
                    child: RecomendacionPanel(
                      resultado: data!.recomendacion,
                      mensaje: data.mensajeReco,
                      onGuardar: _guardarComoOutfit,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Contenedor del panel: handle arriba y fondo que solo se pinta al abrirse.
class _PanelDeslizable extends StatelessWidget {
  const _PanelDeslizable({
    required this.scrollController,
    required this.expandido,
    required this.onToggle,
    required this.child,
  });

  final ScrollController scrollController;
  final bool expandido;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: expandido ? context.wColors.panel : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // El scroll del panel va ligado al arrastre del sheet
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                height: _HomeScreenState._alturaHandle,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 140,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            child,
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
      'Sin datos climáticos. Revisa tu conexión y desliza para reintentar.',
      textAlign: TextAlign.center,
    ),
  );
}
