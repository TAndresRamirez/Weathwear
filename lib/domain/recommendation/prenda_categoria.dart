// El orden del enum es el orden de visualización de las prendas de un outfit
// (OutfitRepository.getAll ordena por categoria.index).
enum PrendaCategoria { superior, inferior, entero, exterior }

// Deriva la categoria desde Prenda.tipo (salida del clasificador)
// Se calcula en codigo
class PrendaCategoriaMapper {
  PrendaCategoriaMapper._();

  static PrendaCategoria fromTipo(String tipo) {
    switch (tipo.trim().toLowerCase()) {
      case 'polera':
        return PrendaCategoria.superior;
      case 'chaqueta':
      // 'poleron' ya no es un tipo propio (se fusionó con Chaqueta);
      // se conserva como alias por si queda algún dato antiguo.
      case 'poleron':
      case 'polerón':
        return PrendaCategoria.exterior;
      case 'pantalon':
      case 'pantalón':
      case 'shorts':
      case 'short':
        return PrendaCategoria.inferior;
      case 'entero':
        return PrendaCategoria.entero;
      default:
        throw ArgumentError('Tipo de prenda desconocido: $tipo');
    }
  }

  // Tipos que produce el clasificador (mismos que labels.txt), para el selector
  static const List<String> tiposValidos = [
    'Polera',
    'Chaqueta',
    'Pantalon',
    'Shorts',
    'Entero',
  ];
}
