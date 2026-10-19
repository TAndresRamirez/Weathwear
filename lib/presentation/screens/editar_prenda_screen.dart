import 'dart:io';

import 'package:flutter/material.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/etl/weathwear_code_mapper.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/presentation/widgets/prenda_clima_fields.dart';

/// Edita tipo, rango de temperatura y condiciones de una prenda ya guardada.
/// Hace pop(true) si se guardaron cambios.
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
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron guardar los cambios')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar prenda')),
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
            onPressed: _tipo == null || _condiciones.isEmpty || _guardando
                ? null
                : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
