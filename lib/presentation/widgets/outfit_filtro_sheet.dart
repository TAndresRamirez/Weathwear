import 'package:flutter/material.dart';
import 'package:weathwear/domain/etl/weathwear_code_mapper.dart';
import 'package:weathwear/domain/outfits/outfit_filtro.dart';
import 'package:weathwear/presentation/widgets/prenda_clima_fields.dart';

/// Hoja inferior de filtros de outfits. Devuelve el filtro elegido
/// (OutfitFiltro() vacío si se limpia) o null si se descarta.
Future<OutfitFiltro?> mostrarFiltroOutfits(
  BuildContext context,
  OutfitFiltro actual,
) => showModalBottomSheet<OutfitFiltro>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FiltroSheet(actual: actual),
);

class _FiltroSheet extends StatefulWidget {
  const _FiltroSheet({required this.actual});
  final OutfitFiltro actual;

  @override
  State<_FiltroSheet> createState() => _FiltroSheetState();
}

class _FiltroSheetState extends State<_FiltroSheet> {
  late OutfitOrden _orden = widget.actual.orden;
  late String? _condicion = widget.actual.condicion;
  late bool _filtrarTemp =
      widget.actual.tempMin != null || widget.actual.tempMax != null;
  late RangeValues _temps = RangoTemperaturaField.ajustar(
    widget.actual.tempMin ?? 10,
    widget.actual.tempMax ?? 25,
  );

  OutfitFiltro _armar() => OutfitFiltro(
    orden: _orden,
    condicion: _condicion,
    tempMin: _filtrarTemp ? _temps.start : null,
    tempMax: _filtrarTemp ? _temps.end : null,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtrar outfits', style: text.titleLarge),
            const SizedBox(height: 16),
            Text('Orden', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<OutfitOrden>(
              segments: const [
                ButtonSegment(
                  value: OutfitOrden.recientes,
                  label: Text('Más recientes'),
                ),
                ButtonSegment(
                  value: OutfitOrden.masUsados,
                  label: Text('Más usados'),
                ),
              ],
              selected: {_orden},
              onSelectionChanged: (s) => setState(() => _orden = s.first),
            ),
            const SizedBox(height: 16),
            Text('Condición climática', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _condicion == null,
                  onSelected: (_) => setState(() => _condicion = null),
                ),
                for (final c in WeathwearCodeMapper.condiciones)
                  ChoiceChip(
                    label: Text(c),
                    selected: _condicion == c,
                    onSelected: (_) => setState(() => _condicion = c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Filtrar por temperatura'),
              value: _filtrarTemp,
              onChanged: (v) => setState(() => _filtrarTemp = v),
            ),
            if (_filtrarTemp)
              RangoTemperaturaField(
                values: _temps,
                onChanged: (v) => setState(() => _temps = v),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const OutfitFiltro()),
                  child: const Text('Limpiar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_armar()),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
