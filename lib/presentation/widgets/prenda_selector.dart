import 'package:flutter/material.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/presentation/widgets/prenda_foto_tile.dart';

/// Fila horizontal de prendas para elegir una; la seleccionada lleva borde.
/// La usan "Crear outfit" y "Registrar uso desde foto".
class PrendaSelector extends StatelessWidget {
  const PrendaSelector({
    super.key,
    required this.titulo,
    required this.prendas,
    required this.seleccionada,
    required this.onTap,
    this.subtitulo,
  });

  final String titulo;

  /// Línea opcional bajo el título (p. ej. lo que detectó el modelo)
  final Widget? subtitulo;

  /// Se muestran en este orden
  final List<PrendaModel> prendas;
  final PrendaModel? seleccionada;
  final ValueChanged<PrendaModel> onTap;

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleSmall),
        if (subtitulo != null) ...[const SizedBox(height: 4), subtitulo!],
        const SizedBox(height: 8),
        if (prendas.isEmpty)
          const Text('No tienes prendas de este tipo.')
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prendas.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = prendas[i];
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
}
