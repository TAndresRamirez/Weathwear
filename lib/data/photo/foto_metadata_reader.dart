import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:weathwear/data/models/coordenadas.dart';

/// Metadatos de una foto que importan para el RF-11.
class FotoMetadata {
  final DateTime fechaHora;

  /// false: la foto no traía fecha EXIF y se usó la de modificación del archivo
  /// (la UI debe avisarlo, porque puede no ser el momento de la captura).
  final bool fechaDesdeExif;

  /// null si la foto no trae GPS (frecuente en fotos de galería en Android).
  final Coordenadas? coordenadas;

  const FotoMetadata({
    required this.fechaHora,
    required this.fechaDesdeExif,
    this.coordenadas,
  });
}

// Lee fecha/hora de captura y GPS desde el EXIF de un JPEG.
// Usa el paquete image (ya es dependencia del clasificador): sin paquetes nuevos.
class FotoMetadataReader {
  // Tags EXIF estándar
  static const int _tagDateTimeOriginal = 0x9003;
  static const int _tagDateTimeDigitized = 0x9004;
  static const int _tagDateTime = 0x0132; // fecha de última edición, último recurso
  static const int _tagGpsLatRef = 0x0001;
  static const int _tagGpsLat = 0x0002;
  static const int _tagGpsLonRef = 0x0003;
  static const int _tagGpsLon = 0x0004;

  // Formato EXIF: "2026:11:05 14:30:00" (hora local del dispositivo, sin zona)
  static final RegExp _formatoFecha = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
  );

  const FotoMetadataReader();

  Future<FotoMetadata> leer(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    // null si no es JPEG o no trae EXIF; decodeJpgExif no lanza excepciones
    final exif = img.decodeJpgExif(bytes);

    final fecha = exif == null ? null : fechaDesdeExif(exif);
    return FotoMetadata(
      fechaHora: fecha ?? await file.lastModified(),
      fechaDesdeExif: fecha != null,
      coordenadas: exif == null ? null : coordenadasDesdeExif(exif),
    );
  }

  /// Públicos y estáticos para testearlos sin generar archivos JPEG.
  static DateTime? fechaDesdeExif(img.ExifData exif) {
    final valor =
        exif.exifIfd[_tagDateTimeOriginal] ??
        exif.exifIfd[_tagDateTimeDigitized] ??
        exif.imageIfd[_tagDateTime];
    return valor == null ? null : parseFechaExif(valor.toString());
  }

  static DateTime? parseFechaExif(String texto) {
    final m = _formatoFecha.firstMatch(texto.trim());
    if (m == null) return null;
    final p = List.generate(6, (i) => int.parse(m.group(i + 1)!));
    // Algunas cámaras escriben "0000:00:00 00:00:00" cuando no tienen hora
    if (p[0] == 0 || p[1] < 1 || p[1] > 12 || p[2] < 1 || p[2] > 31) {
      return null;
    }
    return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  static Coordenadas? coordenadasDesdeExif(img.ExifData exif) {
    final gps = exif.gpsIfd;
    final lat = _gradosDecimales(gps[_tagGpsLat]);
    final lon = _gradosDecimales(gps[_tagGpsLon]);
    if (lat == null || lon == null) return null;

    final latRef = gps[_tagGpsLatRef]?.toString().trim().toUpperCase();
    final lonRef = gps[_tagGpsLonRef]?.toString().trim().toUpperCase();
    final latitud = latRef == 'S' ? -lat : lat;
    final longitud = lonRef == 'W' ? -lon : lon;

    if (latitud.abs() > 90 || longitud.abs() > 180) return null;
    // 0,0 suele ser "sin fix GPS", no una ubicación real
    if (latitud == 0 && longitud == 0) return null;
    return Coordenadas(latitud: latitud, longitud: longitud);
  }

  // EXIF guarda grados, minutos y segundos como 3 racionales.
  // Ojo: IfdDirectory.gpsLatitude del paquete solo devuelve los grados,
  // por eso se calcula a mano.
  static double? _gradosDecimales(img.IfdValue? v) {
    if (v == null || v.length == 0) return null;
    var total = v.toDouble(0);
    if (v.length > 1) total += v.toDouble(1) / 60;
    if (v.length > 2) total += v.toDouble(2) / 3600;
    return total.isFinite ? total : null;
  }
}
