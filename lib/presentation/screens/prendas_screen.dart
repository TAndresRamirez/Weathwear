import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/outfits/outfit_filtro.dart';
import 'package:weathwear/domain/outfits/usar_outfit_use_case.dart';
import 'package:weathwear/domain/recommendation/recommendation_engine.dart';
import 'package:weathwear/presentation/screens/crear_outfit_screen.dart';
import 'package:weathwear/presentation/screens/editar_prenda_screen.dart';
import 'package:weathwear/presentation/screens/registrar_prenda_screen.dart';
import 'package:weathwear/presentation/widgets/outfit_dialog.dart';
import 'package:weathwear/presentation/widgets/outfit_filtro_sheet.dart';
import 'package:weathwear/presentation/widgets/paged_grid.dart';
import 'package:weathwear/presentation/widgets/prenda_imagen.dart';
import 'package:weathwear/core/theme/app_theme.dart';

class PrendasScreen extends StatefulWidget {
  const PrendasScreen({
    super.key,
    this.loader,
    this.outfitsLoader,
    this.climaLoader,
  });

  /// Inyectables para tests. Si son null usa los repositorios reales.
  final Future<List<PrendaModel>> Function()? loader;
  final Future<List<OutfitGuardado>> Function()? outfitsLoader;
  final Future<ClimaModel?> Function()? climaLoader;

  @override
  State<PrendasScreen> createState() => _PrendasScreenState();
}

class _PrendasScreenState extends State<PrendasScreen> {
  final _engine = RecommendationEngine();

  List<PrendaModel> _prendas = const [];
  List<OutfitGuardado> _outfits = const [];
  ClimaModel? _clima; // para la afinidad "de hoy" de cada outfit
  OutfitFiltro _filtro = const OutfitFiltro();

  bool _cargando = true;
  bool _error = false;
  bool _menuAbierto = false;

  bool get _filtroActivo =>
      _filtro.condicion != null ||
      _filtro.tempMin != null ||
      _filtro.tempMax != null ||
      _filtro.orden != OutfitOrden.recientes;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<List<PrendaModel>> _loadPrendas() =>
      widget.loader != null ? widget.loader!() : PrendaRepository().getAll();

  Future<List<OutfitGuardado>> _loadOutfits() => widget.outfitsLoader != null
      ? widget.outfitsLoader!()
      : OutfitRepository().getAll();

  Future<ClimaModel?> _loadClima() => widget.climaLoader != null
      ? widget.climaLoader!()
      : ClimaRepository().getUltimo();

  // Cada lectura termina en un setState con datos nuevos; mientras recarga
  // se sigue mostrando lo anterior (sin parpadeo).
  Future<void> _reload() async {
    try {
      final prendas = await _loadPrendas();
      final outfits = await _loadOutfits();
      final clima = await _loadClima();
      if (!mounted) return;
      setState(() {
        _prendas = prendas;
        _outfits = outfits;
        _clima = clima;
        _error = false;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error recargando prendas/outfits: $e');
      if (!mounted) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  // Abre el registro directo en cámara o galería; al volver, recarga siempre
  Future<void> _abrirRegistro(ImageSource source) async {
    setState(() => _menuAbierto = false);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistrarPrendaScreen(initialSource: source),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _abrirCrearOutfit() async {
    setState(() => _menuAbierto = false);
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CrearOutfitScreen()));
    if (mounted) _reload();
  }

  Future<void> _editar(PrendaModel prenda) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditarPrendaScreen(prenda: prenda)),
    );
    if (mounted) _reload();
  }

  Future<void> _abrirOutfit(OutfitGuardado o, double? afinidad) async {
    final mensaje = await showDialog<String>(
      context: context,
      builder: (_) => OutfitDialog(
        outfit: o,
        afinidad: afinidad,
        onUsar: () => UsarOutfitUseCase(OutfitRepository(), ClimaRepository())(
          o.idOutfit,
        ),
        onEliminar: () => OutfitRepository().eliminar(o.idOutfit),
      ),
    );
    if (!mounted) return;
    if (mensaje != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    }
    _reload(); // siempre: el uso cambia "más usados" y el promedio
  }

  Future<void> _filtrar() async {
    final nuevo = await mostrarFiltroOutfits(context, _filtro);
    if (nuevo != null && mounted) setState(() => _filtro = nuevo);
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomRight,
          child: _menuAbierto
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // heroTag distinto por botón: evita conflicto entre FABs
                    FloatingActionButton.extended(
                      heroTag: 'fab_camara',
                      onPressed: () => _abrirRegistro(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'fab_galeria',
                      onPressed: () => _abrirRegistro(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'fab_outfit',
                      onPressed: _abrirCrearOutfit,
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Crear outfit'),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'fab_principal',
          onPressed: () => setState(() => _menuAbierto = !_menuAbierto),
          tooltip: _menuAbierto ? 'Cerrar' : 'Agregar',
          child: Icon(_menuAbierto ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return const Center(child: Text('No se pudieron cargar las prendas.'));
    }

    final outfits = _filtro.aplicar(_outfits);
    final clima = _clima;

    return Column(
      children: [
        // Últimas prendas agregadas: 2x2 por página
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _prendas.isEmpty
                ? const _Vacio('Aún no tienes prendas registradas.')
                : PagedGrid<PrendaModel>(
                    items: _prendas,
                    columns: 2,
                    rows: 2,
                    itemBuilder: (_, p) =>
                        _PrendaCard(prenda: p, onTap: () => _editar(p)),
                  ),
          ),
        ),
        // Outfits guardados: 3x2 por página
        Expanded(
          flex: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: outfits.isEmpty
                ? _Vacio(
                    _outfits.isEmpty
                        ? 'Aún no tienes outfits. Guarda una recomendación '
                              'desde Hoy o crea uno con "+".'
                        : 'Ningún outfit coincide con el filtro.',
                  )
                : PagedGrid<OutfitGuardado>(
                    items: outfits,
                    columns: 3,
                    rows: 2,
                    itemBuilder: (_, o) {
                      final afinidad = clima == null
                          ? null
                          : _engine.afinidad(clima, o.prendas);
                      return _OutfitCard(
                        outfit: o,
                        afinidad: afinidad,
                        onTap: () => _abrirOutfit(o, afinidad),
                      );
                    },
                  ),
          ),
        ),
        // Fila inferior: el FAB (abajo a la derecha) no tapa el contenido
        SizedBox(
          height: 72,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: FilledButton.tonalIcon(
                onPressed: _filtrar,
                icon: Icon(
                  _filtroActivo ? Icons.filter_alt : Icons.filter_alt_outlined,
                ),
                label: Text(_filtroActivo ? 'Filtrar •' : 'Filtrar'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFab(),
      body: _cuerpo(),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.mensaje);
  final String mensaje;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(mensaje, textAlign: TextAlign.center));
}

/// Foto, tipo y condición climática principal de la prenda.
class _PrendaCard extends StatelessWidget {
  const _PrendaCard({required this.prenda, required this.onTap});
  final PrendaModel prenda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.panelText;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // InkWell dentro del Card: el ripple se dibuja sobre la imagen
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: PrendaImagen(prenda: prenda, radius: 0)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prenda.tipo, style: text.titleSmall),
                  Text(
                    prenda.condiciones.firstOrNull ?? '—',
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fotos de la prenda superior e inferior y afinidad con el clima de hoy.
class _OutfitCard extends StatelessWidget {
  const _OutfitCard({
    required this.outfit,
    required this.afinidad,
    required this.onTap,
  });

  final OutfitGuardado outfit;
  final double? afinidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: PrendaImagen(prenda: outfit.superior)),
                    const SizedBox(width: 4),
                    Expanded(child: PrendaImagen(prenda: outfit.inferior)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                afinidad == null
                    ? 'Afinidad --'
                    : 'Afinidad ${(afinidad! * 100).round()}%',
                style: context.panelText.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
