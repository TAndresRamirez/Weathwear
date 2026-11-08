import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/uso/obtener_clima_foto_use_case.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';

/// Propuesta para una categoría del outfit (superior, inferior, entero, exterior).
class SlotPropuesta {
  final PrendaCategoria categoria;

  /// Lo que vio el modelo en la zona que corresponde (null: no detectó esta categoría)
  final ClassificationResult? deteccion;

  /// Prendas activas de la categoría, la propuesta primero; para el selector
  final List<PrendaModel> candidatas;

  /// null: el usuario debe elegir (o, en exterior, no lleva)
  final PrendaModel? propuesta;

  const SlotPropuesta({
    required this.categoria,
    required this.deteccion,
    required this.candidatas,
    required this.propuesta,
  });

  /// La UI resalta el slot cuando la propuesta no viene respaldada por el modelo.
  bool get requiereConfirmacion {
    final d = deteccion;
    final p = propuesta;
    if (d == null || p == null) return true;
    return d.confidence < RegistrarUsoFotoUseCase.umbralConfianza ||
        !RegistrarUsoFotoUseCase.mismoTipo(p.tipo, d.label);
  }
}

class PropuestaUso {
  final ClimaFoto clima;

  /// true si el modelo vio una prenda entera: la UI muestra entero en vez de
  /// superior + inferior (el usuario puede cambiar el modo)
  final bool esEntero;

  /// Siempre trae las 4 categorías para poder cambiar de modo sin reanalizar.
  final Map<PrendaCategoria, SlotPropuesta> slots;

  const PropuestaUso({
    required this.clima,
    required this.esEntero,
    required this.slots,
  });
}

class RegistroUsoResultado {
  final int idOutfit;
  final bool outfitNuevo; // no existía un outfit con esas prendas
  final bool usoRegistrado; // false: ese outfit ya tenía un uso ese día
  const RegistroUsoResultado(
    this.idOutfit, {
    required this.outfitNuevo,
    required this.usoRegistrado,
  });
}

// RF-10: foto de la persona vestida -> prendas propuestas -> confirmar/corregir
// -> uso registrado con el clima del momento de la foto (RF-11).
// Igual que RegistrarPrendaUseCase, en dos pasos para que el usuario confirme
// antes de persistir: proponer() no escribe nada salvo el clima.
class RegistrarUsoFotoUseCase {
  static const double umbralConfianza = 0.70;

  // Franjas de una foto de cuerpo completo, vertical y de frente. Se solapan
  // a propósito porque la cintura no cae siempre a la misma altura.
  static const ZonaVertical zonaSuperior = (desde: 0.12, hasta: 0.55);
  static const ZonaVertical zonaInferior = (desde: 0.50, hasta: 0.95);
  static const ZonaVertical zonaCuerpo = (desde: 0.10, hasta: 0.95);

  final ClothingClassifier _classifier;
  final PrendaRepository _prendaRepo;
  final OutfitRepository _outfitRepo;
  final Future<ClimaFoto> Function(String imagePath) _obtenerClima;

  RegistrarUsoFotoUseCase(
    this._classifier, {
    PrendaRepository? prendaRepo,
    OutfitRepository? outfitRepo,
    Future<ClimaFoto> Function(String imagePath)? obtenerClima,
  }) : _prendaRepo = prendaRepo ?? PrendaRepository(),
       _outfitRepo = outfitRepo ?? OutfitRepository(),
       _obtenerClima = obtenerClima ?? ObtenerClimaFotoUseCase().call;

  Future<PropuestaUso> proponer(String imagePath) async {
    // El clima (red) corre en paralelo con la clasificación (CPU)
    final climaFuture = _obtenerClima(imagePath);
    // Listener inmediato: si el clima falla mientras se clasifica, Dart no lo
    // reporta como error no manejado. El error igual llega en el await de abajo.
    climaFuture.then((_) {}, onError: (_) {});

    if (!_classifier.isLoaded) await _classifier.load();
    final detecciones = await _classifier.classifyZonas(imagePath, const [
      zonaSuperior,
      zonaInferior,
      zonaCuerpo,
    ]);
    final prendas = await _prendaRepo.getAll();
    final usos = await _outfitRepo.usosPorPrenda();
    final clima = await climaFuture;

    final sup = detecciones[0];
    final inf = detecciones[1];
    final cuerpo = detecciones[2];

    // Cada zona solo aporta a las categorías que pueden estar ahí
    ClassificationResult? si(ClassificationResult d, PrendaCategoria c) =>
        _categoriaDe(d.label) == c ? d : null;

    final detEntero =
        si(cuerpo, PrendaCategoria.entero) ?? si(sup, PrendaCategoria.entero);
    final detExterior =
        si(sup, PrendaCategoria.exterior) ??
        si(cuerpo, PrendaCategoria.exterior);

    SlotPropuesta slot(PrendaCategoria c, ClassificationResult? det) =>
        _armarSlot(c, det, prendas, usos);

    return PropuestaUso(
      clima: clima,
      esEntero: detEntero != null && detEntero.confidence >= umbralConfianza,
      slots: {
        PrendaCategoria.superior: slot(
          PrendaCategoria.superior,
          si(sup, PrendaCategoria.superior),
        ),
        PrendaCategoria.inferior: slot(
          PrendaCategoria.inferior,
          si(inf, PrendaCategoria.inferior),
        ),
        PrendaCategoria.entero: slot(PrendaCategoria.entero, detEntero),
        PrendaCategoria.exterior: slot(PrendaCategoria.exterior, detExterior),
      },
    );
  }

  /// Persiste lo que confirmó el usuario: reutiliza el outfit si ya existe
  /// con esas prendas exactas; si no, lo crea con origen "foto".
  /// El uso queda con la fecha de la foto, no con la de hoy.
  Future<RegistroUsoResultado> registrar({
    required ClimaFoto clima,
    required List<PrendaModel> prendas,
  }) async {
    final ids = GuardarOutfitUseCase.validar(prendas); // OutfitException
    final idClima = clima.clima.idClima;
    if (idClima == null) {
      throw const OutfitException('El clima de la foto no está guardado');
    }

    final existente = await _outfitRepo.buscarIdPorPrendas(ids);
    final idOutfit =
        existente ??
        await _outfitRepo.insert(
          idsPrenda: ids.toList(),
          origen: OutfitOrigen.foto,
        );
    final registrado = await _outfitRepo.registrarUso(
      idOutfit: idOutfit,
      idClima: idClima,
      fecha: clima.metadata.fechaHora,
    );
    return RegistroUsoResultado(
      idOutfit,
      outfitNuevo: existente == null,
      usoRegistrado: registrado,
    );
  }

  // Candidatas: mismo tipo detectado primero, luego más usadas, luego más recientes.
  // Superior/inferior/entero siempre proponen algo (la "más probable");
  // exterior solo si el modelo vio una chaqueta, porque es opcional.
  static SlotPropuesta _armarSlot(
    PrendaCategoria categoria,
    ClassificationResult? det,
    List<PrendaModel> prendas,
    Map<int, int> usos,
  ) {
    int rangoTipo(PrendaModel p) =>
        det != null && mismoTipo(p.tipo, det.label) ? 0 : 1;

    final candidatas = prendas.where((p) => p.categoria == categoria).toList()
      ..sort((a, b) {
        final porTipo = rangoTipo(a).compareTo(rangoTipo(b));
        if (porTipo != 0) return porTipo;
        final porUso = (usos[b.idPrenda] ?? 0).compareTo(usos[a.idPrenda] ?? 0);
        if (porUso != 0) return porUso;
        return (b.idPrenda ?? 0).compareTo(a.idPrenda ?? 0);
      });

    final PrendaModel? propuesta;
    if (categoria == PrendaCategoria.exterior) {
      propuesta = det != null && det.confidence >= umbralConfianza
          ? candidatas.firstOrNull
          : null;
    } else {
      propuesta = candidatas.firstOrNull;
    }

    return SlotPropuesta(
      categoria: categoria,
      deteccion: det,
      candidatas: candidatas,
      propuesta: propuesta,
    );
  }

  static PrendaCategoria? _categoriaDe(String label) {
    try {
      return PrendaCategoriaMapper.fromTipo(label);
    } on ArgumentError {
      return null; // etiqueta desconocida: la zona no aporta
    }
  }

  /// Compara tipos ignorando mayúsculas y tildes ("Pantalón" == "Pantalon").
  static bool mismoTipo(String a, String b) => _norm(a) == _norm(b);

  static String _norm(String s) => s.trim().toLowerCase().replaceAll('ó', 'o');
}
