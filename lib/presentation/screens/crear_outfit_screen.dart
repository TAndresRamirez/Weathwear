import 'package:flutter/material.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/presentation/widgets/app_background.dart';
import 'package:weathwear/presentation/widgets/prenda_foto_tile.dart';

/// Arma un outfit a mano: superior + inferior, o una prenda entera, y
/// opcionalmente una exterior. Hace pop(true) si se guardó.
class CrearOutfitScreen extends StatefulWidget {
  const CrearOutfitScreen({super.key, this.prendasLoader, this.guardar});

  /// Inyectables para tests. Si son null se usan los reales.
  final Future<List<PrendaModel>> Function()? prendasLoader;
  final Future<int> Function(List<PrendaModel> prendas)? guardar;

  @override
  State<CrearOutfitScreen> createState() => _CrearOutfitScreenState();
}

class _CrearOutfitScreenState extends State<CrearOutfitScreen> {
  List<PrendaModel>? _prendas;
  bool _error = false;
  bool _guardando = false;
  PrendaModel? _superior;
  PrendaModel? _inferior;
  PrendaModel? _entero;
  PrendaModel? _exterior;

  // Superior + inferior, o una prenda entera
  bool get _composicionCompleta =>
      _entero != null || (_superior != null && _inferior != null);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final prendas =
          await (widget.prendasLoader ?? PrendaRepository().getAll)();
      if (mounted) setState(() => _prendas = prendas);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<int> _guardarReal(List<PrendaModel> prendas) =>
      GuardarOutfitUseCase(OutfitRepository())(prendas);

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Los null-aware elements omiten las categorías no elegidas
      await (widget.guardar ?? _guardarReal)([
        ?_superior,
        ?_inferior,
        ?_entero,
        ?_exterior,
      ]);
      if (mounted) Navigator.of(context).pop(true);
    } on OutfitException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo guardar el outfit');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // Tocar la seleccionada la deselecciona
  PrendaModel? _alternar(PrendaModel? actual, PrendaModel p) =>
      actual?.idPrenda == p.idPrenda ? null : p;

  Widget _seccion(
    String titulo,
    PrendaCategoria categoria,
    PrendaModel? seleccionada,
    ValueChanged<PrendaModel> onTap,
  ) {
    final lista = _prendas!
        .where((p) => p.categoria == categoria)
        .toList(growable: false);
    final primario = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          const Text('No tienes prendas de este tipo.')
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = lista[i];
                final activa = seleccionada?.idPrenda == p.idPrenda;
                return GestureDetector(
                  onTap: () => onTap(p),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        width: 3,
                        color: activa ? primario : Colors.transparent,
                      ),
                    ),
                    child: PrendaFotoTile(prenda: p, size: 96),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final puedeGuardar = _composicionCompleta && !_guardando;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Crear outfit'),
          backgroundColor: Colors.transparent,
        ),
        body: _cuerpo(puedeGuardar),
      ),
    );
  }

  Widget _cuerpo(bool puedeGuardar) {
    if (_error) {
      return const Center(child: Text('No se pudieron cargar las prendas.'));
    }
    if (_prendas == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_prendas!.isEmpty) {
      return const Center(
        child: Text('Primero registra prendas para crear un outfit.'),
      );
    }

    // La sección "Entero" solo aparece si el usuario tiene prendas enteras
    final hayEnteros = _prendas!.any(
      (p) => p.categoria == PrendaCategoria.entero,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _seccion(
                'Prenda superior',
                PrendaCategoria.superior,
                _superior,
                (p) => setState(() {
                  _superior = _alternar(_superior, p);
                  if (_superior != null) _entero = null; // excluyente
                }),
              ),
              const SizedBox(height: 16),
              _seccion(
                'Prenda inferior',
                PrendaCategoria.inferior,
                _inferior,
                (p) => setState(() {
                  _inferior = _alternar(_inferior, p);
                  if (_inferior != null) _entero = null;
                }),
              ),
              if (hayEnteros) ...[
                const SizedBox(height: 16),
                _seccion(
                  'Prenda entera (reemplaza superior e inferior)',
                  PrendaCategoria.entero,
                  _entero,
                  (p) => setState(() {
                    _entero = _alternar(_entero, p);
                    if (_entero != null) {
                      _superior = null;
                      _inferior = null;
                    }
                  }),
                ),
              ],
              const SizedBox(height: 16),
              _seccion(
                'Prenda exterior (opcional)',
                PrendaCategoria.exterior,
                _exterior,
                (p) => setState(() => _exterior = _alternar(_exterior, p)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: puedeGuardar ? _guardar : null,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar outfit'),
            ),
          ),
        ),
      ],
    );
  }
}
