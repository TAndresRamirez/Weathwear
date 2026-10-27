import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Grilla paginada: cada página es una grilla de [columns] x [rows] que se
/// desliza horizontalmente, con puntos indicadores debajo.
/// Se adapta al alto disponible (úsala dentro de un Expanded).
class PagedGrid<T> extends StatefulWidget {
  const PagedGrid({
    super.key,
    required this.items,
    required this.columns,
    required this.rows,
    required this.itemBuilder,
    this.spacing = 12,
  });

  final List<T> items;
  final int columns;
  final int rows;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double spacing;

  @override
  State<PagedGrid<T>> createState() => _PagedGridState<T>();
}

class _PagedGridState<T> extends State<PagedGrid<T>> {
  static const double _alturaPuntos = 24;
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final porPagina = widget.columns * widget.rows;
    final paginas = math.max(1, (widget.items.length / porPagina).ceil());
    // Si se eliminan elementos, la página actual puede dejar de existir
    final actual = _pagina.clamp(0, paginas - 1).toInt();

    return LayoutBuilder(
      builder: (context, box) {
        final altoGrid = box.maxHeight - _alturaPuntos;
        final ancho =
            (box.maxWidth - widget.spacing * (widget.columns - 1)) /
            widget.columns;
        final alto =
            (altoGrid - widget.spacing * (widget.rows - 1)) / widget.rows;

        return Column(
          children: [
            SizedBox(
              height: altoGrid,
              child: PageView.builder(
                itemCount: paginas,
                onPageChanged: (p) => setState(() => _pagina = p),
                itemBuilder: (context, p) {
                  final inicio = p * porPagina;
                  final fin = math.min(inicio + porPagina, widget.items.length);
                  return GridView.count(
                    // Sin padding: por defecto un scroll agrega el del sistema
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: widget.columns,
                    mainAxisSpacing: widget.spacing,
                    crossAxisSpacing: widget.spacing,
                    childAspectRatio: ancho / math.max(alto, 1),
                    children: [
                      for (final item in widget.items.sublist(inicio, fin))
                        widget.itemBuilder(context, item),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              height: _alturaPuntos,
              child: PageDots(count: paginas, index: actual),
            ),
          ],
        );
      },
    );
  }
}

/// Puntos de paginación. Con una sola página no se dibuja nada.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? color : color.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
