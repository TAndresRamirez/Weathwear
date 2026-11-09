import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/domain/recommendation/generar_recomendacion_use_case.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/presentation/widgets/outfit_prendas_view.dart';

/// Contenido del panel deslizable: superior + inferior (o entero) y, si existe,
/// exterior, con su justificación. Si viene del historial y hay un segundo
/// conjunto, permite alternar entre la recomendación y la alternativa.
class RecomendacionPanel extends StatefulWidget {
  const RecomendacionPanel({
    super.key,
    required this.onGuardar,
    required this.onUsar,
    this.resultado,
    this.mensaje,
  });

  final RecomendacionResultado? resultado;
  final String? mensaje; // por qué no hay recomendación

  /// Respaldo por rango: el conjunto aún no existe como outfit guardado
  final ValueChanged<Outfit> onGuardar;

  /// Historial: el conjunto ya es un outfit; se registra su uso (id_outfit)
  final ValueChanged<int> onUsar;

  @override
  State<RecomendacionPanel> createState() => _RecomendacionPanelState();
}

class _RecomendacionPanelState extends State<RecomendacionPanel> {
  bool _verAlternativa = false;

  @override
  void didUpdateWidget(RecomendacionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nueva recomendación (recarga): vuelve a mostrar la principal
    if (oldWidget.resultado != widget.resultado) _verAlternativa = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = widget.resultado;
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
            child: Text(
              _verAlternativa ? 'Alternativa' : 'Recomendación del Día',
              style: text.titleSmall,
            ),
          ),
          const SizedBox(height: 16),
          if (r == null)
            Text(
              widget.mensaje ?? 'Sin recomendación disponible',
              textAlign: TextAlign.center,
            )
          else
            ..._contenido(context, r),
        ],
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, RecomendacionResultado r) {
    final text = Theme.of(context).textTheme;
    final alternativa = r.alternativa;
    final mostrada = _verAlternativa && alternativa != null
        ? alternativa
        : r.historial;
    final outfit = mostrada?.outfit ?? r.outfit;
    final justificacion = mostrada?.justificacion ?? r.justificacion;

    return [
      if (r.climaDesactualizado)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'El clima tiene más de 3 horas; desliza para actualizar.',
            style: text.bodySmall,
          ),
        ),
      OutfitPrendasView(
        principales: outfit.principales,
        exterior: outfit.exterior,
      ),
      const SizedBox(height: 12),
      Text(
        'Afinidad: ${(outfit.similitud * 100).round()}%',
        style: text.bodySmall,
      ),
      const SizedBox(height: 4),
      Text(justificacion, style: text.bodySmall, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (mostrada != null)
            FilledButton.tonalIcon(
              onPressed: () => widget.onUsar(mostrada.idOutfit),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Usar hoy'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => widget.onGuardar(outfit),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Guardar como outfit'),
            ),
          if (alternativa != null)
            TextButton(
              onPressed: () =>
                  setState(() => _verAlternativa = !_verAlternativa),
              child: Text(
                _verAlternativa ? 'Ver recomendación' : 'Ver alternativa',
              ),
            ),
        ],
      ),
    ];
  }
}
