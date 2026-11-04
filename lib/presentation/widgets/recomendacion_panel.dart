import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/presentation/widgets/outfit_prendas_view.dart';

/// Contenido del panel deslizable: superior + inferior (o entero) y, si existe, exterior.
class RecomendacionPanel extends StatelessWidget {
  const RecomendacionPanel({
    super.key,
    required this.onGuardar,
    this.resultado,
    this.mensaje,
  });

  final RecomendacionResultado? resultado;
  final String? mensaje; // por qué no hay recomendación
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = resultado;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: context.wColors.tarjeta,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Recomendación del Día', style: text.titleSmall),
          ),
          const SizedBox(height: 16),
          if (r == null)
            Text(
              mensaje ?? 'Sin recomendación disponible',
              textAlign: TextAlign.center,
            )
          else ...[
            if (r.climaDesactualizado)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'El clima tiene más de 3 horas; desliza para actualizar.',
                  style: text.bodySmall,
                ),
              ),
            OutfitPrendasView(
              principales: r.outfit.principales,
              exterior: r.outfit.exterior,
            ),
            const SizedBox(height: 12),
            Text(
              'Afinidad: ${(r.outfit.similitud * 100).round()}%',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: onGuardar,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Guardar como outfit'),
            ),
          ],
        ],
      ),
    );
  }
}
