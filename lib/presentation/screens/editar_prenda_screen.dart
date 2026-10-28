import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/etl/weathwear_code_mapper.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/presentation/widgets/app_background.dart';
import 'package:weathwear/presentation/widgets/prenda_clima_fields.dart';

/// Edita tipo, rango de temperatura y condiciones de una prenda ya guardada,
/// o la elimina. Hace pop(true) si hubo cambios (guardados o eliminación).
class EditarPrendaScreen extends StatefulWidget {
  const EditarPrendaScreen({super.key, required this.prenda, this.repository});

  final PrendaModel prenda;

  /// Inyectable para tests. Si es null usa el repositorio real.
  final PrendaRepository? repository;

  @override
  State<EditarPrendaScreen> createState() => _EditarPrendaScreenState();
}

class _EditarPrendaScreenState extends State<EditarPrendaScreen> {
  late final PrendaRepository _repository =
      widget.repository ?? PrendaRepository();

  // Si el tipo guardado no está en la lista (dato antiguo), queda null y el
  // usuario debe elegirlo; evita el assert del DropdownButton
  late String? _tipo =
      PrendaCategoriaMapper.tiposValidos.contains(widget.prenda.tipo)
      ? widget.prenda.tipo
      : null;
  late RangeValues _temps = RangoTemperaturaField.ajustar(
    widget.prenda.tempMin,
    widget.prenda.tempMax,
  );
  late final Set<String> _condiciones = widget.prenda.condiciones.toSet();

  // Bloquea guardar y eliminar mientras hay una operación en curso
  bool _ocupado = false;

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    try {
      await _repository.update(
        widget.prenda.copyWith(
          tipo: _tipo,
          tempMin: _temps.start,
          tempMax: _temps.end,
          // Orden canónico, separado por comas (igual que en el registro)
          condicionAplicable: WeathwearCodeMapper.condiciones
              .where(_condiciones.contains)
              .join(','),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _snack('No se pudieron guardar los cambios');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // Borrado lógico (desactivar), no DELETE: Recomendacion y OutfitPrenda
  // referencian la prenda con ON DELETE RESTRICT, y el historial debe
  // seguir mostrando sus fotos.
  Future<void> _eliminar() async {
    final id = widget.prenda.idPrenda;
    if (id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar esta prenda?'),
        content: const Text(
          'Dejará de aparecer en tus prendas y en las recomendaciones. '
          'Los outfits que la incluyan también se ocultarán. '
          'El historial se conserva.',
        ),
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

    setState(() => _ocupado = true);
    try {
      await _repository.desactivar(id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _snack('No se pudo eliminar la prenda');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Editar prenda'),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar prenda',
              onPressed: _ocupado ? null : _eliminar,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 200,
              child: Image.file(
                File(widget.prenda.imagenRuta),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              child: DropdownButton<String>(
                value: _tipo,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                hint: const Text('Elige el tipo'),
                items: [
                  for (final t in PrendaCategoriaMapper.tiposValidos)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                // Al editar NO se pisa el rango: solo cambia el tipo
                onChanged: (t) => setState(() => _tipo = t),
              ),
            ),
            const SizedBox(height: 16),
            RangoTemperaturaField(
              values: _temps,
              onChanged: (v) => setState(() => _temps = v),
            ),
            const SizedBox(height: 8),
            CondicionesField(
              seleccionadas: _condiciones,
              onChanged: (c, seleccionada) => setState(() {
                if (seleccionada) {
                  _condiciones.add(c);
                } else {
                  _condiciones.remove(c);
                }
              }),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _tipo == null || _condiciones.isEmpty || _ocupado
                  ? null
                  : _guardar,
              child: _ocupado
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
