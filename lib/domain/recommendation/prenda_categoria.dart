enum PrendaCategoria { superior, inferior, exterior }

// Deriva la categoria desde Prenda.tipo (salida del clasificador)
// Se calcula en codigo

class PrendaCategoriaMapper {
  PrendaCategoriaMapper._();

  static PrendaCategoria fromTipo(String tipo) {
    switch (tipo.trim().toLowerCase()) {
      case 'polera':
      case 'poleron':
      case 'polerón':
        return PrendaCategoria.superior;
      case 'chaqueta':
        return PrendaCategoria.exterior;
      case 'pantalon':
      case 'pantalón':
      case 'shorts':
      case 'short':
        return PrendaCategoria.inferior;
      default:
        throw ArgumentError('Tipo de prenda desconocido: $tipo');
    }
  }

  // Tipos que produce el clasificador (mismos que labels.txt), para el selector
  static const List<String> tiposValidos = [
    'Polera',
    'Poleron',
    'Chaqueta',
    'Pantalon',
    'Shorts',
  ];
}
