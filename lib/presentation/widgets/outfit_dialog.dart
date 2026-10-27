import 'package:flutter/material.dart';
import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';
import 'package:weathwear/presentation/widgets/prenda_foto_tile.dart';

/// Detalle de un outfit: fotos grandes, datos y acciones (usar hoy / eliminar).
/// Al cerrarse devuelve el mensaje a mostrar en un SnackBar (o null).
class OutfitDialog extends StatefulWidget {
  const OutfitDialog({
    super.key,
    required this.outfit,
    required this.afinidad,
    required this.onUsar,
    required this.onEliminar,
  });

  final OutfitGuardado outfit;
  final double? afinidad; // contra el clima de hoy; null si no hay clima
  final Future<bool> Function() onUsar; // false = ya estaba registrado hoy
  final Future<void> Function() onEliminar;

  @override
  State<OutfitDialog> createState() => _OutfitDialogState();
}

class _OutfitDialogState extends State<OutfitDialog> {
  bool _ocupado = false;
  String? _error;

  // Ejecuta una acción; si sale bien cierra el diálogo con un mensaje,
  // si falla muestra el error dentro del propio diálogo.
  Future<void> _ejecutar(
    Future<String> Function() accion,
    String errorGenerico,
  ) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final mensaje = await accion();
      if (mounted) Navigator.of(context).pop(mensaje);
    } on OutfitException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = errorGenerico);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _usar() => _ejecutar(() async {
    final nuevo = await widget.onUsar();
    return nuevo
        ? 'Outfit registrado para hoy'
        : 'Ya registraste este outfit hoy';
  }, 'No se pudo registrar el uso');

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar este outfit?'),
        content: const Text('También se borrará su registro de usos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _ejecutar(() async {
      await widget.onEliminar();
      return 'Outfit eliminado';
    }, 'No se pudo eliminar el outfit');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outfit;
    final text = Theme.of(context).textTheme;
    final rango = o.rangoTemperatura;
    final condiciones = o.condicionesComunes;

    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Outfit', style: text.titleLarge)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar outfit',
                  onPressed: _ocupado ? null : _eliminar,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PrendaFotoTile(prenda: o.superior, size: 112),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add, size: 28),
                ),
                PrendaFotoTile(prenda: o.inferior, size: 112),
              ],
            ),
            if (o.exterior != null) ...[
              const SizedBox(height: 12),
              Center(child: PrendaFotoTile(prenda: o.exterior!, size: 112)),
            ],
            const SizedBox(height: 16),
            _Dato(
              'Rango de temperatura',
              '${rango.min.round()}–${rango.max.round()}°C',
            ),
            _Dato(
              'Condiciones',
              condiciones.isEmpty ? '—' : condiciones.join(', '),
            ),
            _Dato(
              'Afinidad hoy',
              widget.afinidad == null
                  ? '--'
                  : '${(widget.afinidad! * 100).round()}%',
            ),
            _Dato(
              'Usos',
              o.vecesUsado == 0
                  ? 'Sin usos aún'
                  : '${o.vecesUsado} · promedio '
                        '${o.tempPromedioUso!.toStringAsFixed(1)}°C',
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _ocupado ? null : _usar,
              icon: const Icon(Icons.check),
              label: const Text('Usar hoy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.label, this.valor);
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodyMedium),
          Flexible(
            child: Text(
              valor,
              style: text.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
