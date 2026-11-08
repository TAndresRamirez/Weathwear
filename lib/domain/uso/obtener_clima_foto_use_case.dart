import 'package:weathwear/data/api/clima_api_client.dart';
import 'package:weathwear/data/api/clima_api_exception.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/coordenadas.dart';
import 'package:weathwear/data/photo/foto_metadata_reader.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/storage/ubicacion_storage.dart';
import 'package:weathwear/domain/etl/clima_transformer.dart';

class ClimaFotoException implements Exception {
  final String message;
  const ClimaFotoException(this.message);
  @override
  String toString() => message;
}

/// De dónde salieron las coordenadas usadas (se muestra en la UI y el informe).
enum OrigenUbicacion { foto, guardada, porDefecto }

class ClimaFoto {
  final ClimaModel clima; // ya persistido: idClima != null
  final FotoMetadata metadata;
  final Coordenadas coordenadas;
  final OrigenUbicacion origenUbicacion;

  /// true si se reutilizó un registro del ETL en vez de consultar la API
  final bool reutilizado;

  const ClimaFoto({
    required this.clima,
    required this.metadata,
    required this.coordenadas,
    required this.origenUbicacion,
    required this.reutilizado,
  });
}

// RF-11: metadatos de la foto -> clima de ese momento y lugar -> tabla Clima.
// Guardar en Clima permite que OutfitUso siga apuntando a un id_clima, así
// Historial y las estadísticas de outfits funcionan sin cambios.
class ObtenerClimaFotoUseCase {
  // Margen para relojes desfasados entre cámara y teléfono
  static const Duration _margenFuturo = Duration(minutes: 5);

  final FotoMetadataReader _reader;
  final ClimaRepository _climaRepo;
  final Future<Coordenadas?> Function() _ubicacionGuardada;
  final ClimaApiClient Function() _apiFactory;
  final ClimaTransformer _transformer;
  final DateTime Function() _now;

  ObtenerClimaFotoUseCase({
    FotoMetadataReader? reader,
    ClimaRepository? climaRepo,
    Future<Coordenadas?> Function()? ubicacionGuardada,
    // Fábrica: ClimaApiClient cierra su http.Client en dispose(), así que
    // se crea uno por consulta (igual que el EtlPipeline).
    ClimaApiClient Function()? apiFactory,
    ClimaTransformer? transformer,
    DateTime Function()? now,
  }) : _reader = reader ?? const FotoMetadataReader(),
       _climaRepo = climaRepo ?? ClimaRepository(),
       _ubicacionGuardada = ubicacionGuardada ?? UbicacionStorage().leer,
       _apiFactory = apiFactory ?? ClimaApiClient.new,
       _transformer = transformer ?? ClimaTransformer(),
       _now = now ?? DateTime.now;

  Future<ClimaFoto> call(String imagePath) async {
    final meta = await _reader.leer(imagePath);
    if (meta.fechaHora.isAfter(_now().add(_margenFuturo))) {
      throw const ClimaFotoException(
        'La fecha de la foto es posterior a la actual',
      );
    }

    final (coords, origen) = await _resolverUbicacion(meta);

    // Sin GPS en la foto, las coordenadas son las mismas que usa el ETL:
    // si ya hay un registro de esa hora, se reutiliza.
    if (origen != OrigenUbicacion.foto) {
      final existente = await _climaRepo.buscarCercano(meta.fechaHora);
      if (existente != null) {
        return ClimaFoto(
          clima: existente,
          metadata: meta,
          coordenadas: coords,
          origenUbicacion: origen,
          reutilizado: true,
        );
      }
    }

    final api = _apiFactory();
    try {
      final raw = await api.fetchClimaHistorico(
        fechaHora: meta.fechaHora,
        latitude: coords.latitud,
        longitude: coords.longitud,
        ahora: _now(),
      );
      final clima = _transformer.transform(raw);
      final id = await _climaRepo.insert(clima);
      return ClimaFoto(
        clima: clima.withId(id),
        metadata: meta,
        coordenadas: coords,
        origenUbicacion: origen,
        reutilizado: false,
      );
    } on ClimaApiException catch (e) {
      throw ClimaFotoException(e.message);
    } finally {
      api.dispose();
    }
  }

  // GPS de la foto > última ubicación guardada > Santiago
  Future<(Coordenadas, OrigenUbicacion)> _resolverUbicacion(
    FotoMetadata meta,
  ) async {
    final deFoto = meta.coordenadas;
    if (deFoto != null) return (deFoto, OrigenUbicacion.foto);
    final guardada = await _ubicacionGuardada();
    if (guardada != null) return (guardada, OrigenUbicacion.guardada);
    return (Coordenadas.santiago, OrigenUbicacion.porDefecto);
  }
}
