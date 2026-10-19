import 'package:flutter/material.dart';
import 'package:weathwear/domain/etl/weathwear_code_mapper.dart';

/// Slider de rango de temperatura, compartido por registro y edición.
class RangoTemperaturaField extends StatelessWidget {
  const RangoTemperaturaField({
    super.key,
    required this.values,
    required this.onChanged,
  });

  static const double minTemp = -5;
  static const double maxTemp = 40;

  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  /// Ajusta un rango guardado a los límites del slider
  /// (RangeSlider lanza un assert si los valores se salen de min/max).
  static RangeValues ajustar(double min, double max) => RangeValues(
    min.clamp(minTemp, maxTemp).toDouble(),
    max.clamp(minTemp, maxTemp).toDouble(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rango de temperatura: ${values.start.round()}°C a ${values.end.round()}°C',
        ),
        RangeSlider(
          values: values,
          min: minTemp,
          max: maxTemp,
          divisions: (maxTemp - minTemp).round(),
          labels: RangeLabels(
            '${values.start.round()}°C',
            '${values.end.round()}°C',
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Checklist de condiciones climáticas (selección múltiple).
class CondicionesField extends StatelessWidget {
  const CondicionesField({
    super.key,
    required this.seleccionadas,
    required this.onChanged,
  });

  final Set<String> seleccionadas;
  final void Function(String condicion, bool seleccionada) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condiciones climáticas (elige una o más)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in WeathwearCodeMapper.condiciones)
              FilterChip(
                label: Text(c),
                selected: seleccionadas.contains(c),
                onSelected: (seleccionada) => onChanged(c, seleccionada),
              ),
          ],
        ),
      ],
    );
  }
}
