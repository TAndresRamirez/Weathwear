import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/presentation/widgets/prenda_foto_tile.dart';
import 'package:weathwear/data/models/prenda_model.dart';

/// Contenido del panel deslizable: superior + inferior (+ exterior si existe).
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
    // Todo el contenido está sobre el panel: texto oscuro
    final text = context.panelText;
    final iconColor = context.wColors.textoPanel;
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
              style: text.bodyMedium,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PrendaFotoTile(prenda: r.outfit.superior, sobrePanel: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.add, size: 36, color: iconColor),
                ),
                PrendaFotoTile(prenda: r.outfit.inferior, sobrePanel: true),
              ],
            ),
            const SizedBox(height: 12),
            _FilaExterior(exterior: r.outfit.exterior, onGuardar: onGuardar),
            const SizedBox(height: 12),
            Text(
              'Afinidad: ${(r.outfit.similitud * 100).round()}%',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de la prenda 3: el botón de guardar queda a su izquierda y la prenda
/// centrada. Sin prenda exterior, el botón queda solo y centrado.
class _FilaExterior extends StatelessWidget {
  const _FilaExterior({required this.exterior, required this.onGuardar});

  final PrendaModel? exterior;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final boton = IconButton.filledTonal(
      onPressed: onGuardar,
      icon: const Icon(Icons.bookmark_add_outlined),
      tooltip: 'Guardar como outfit',
    );

    final prenda = exterior;
    if (prenda == null) return Center(child: boton);

    // Dos Expanded simétricos mantienen la prenda en el centro exacto
    return Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: boton),
        ),
        const SizedBox(width: 12),
        PrendaFotoTile(prenda: prenda, sobrePanel: true),
        const SizedBox(width: 12),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
