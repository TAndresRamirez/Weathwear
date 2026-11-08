import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:weathwear/data/photo/foto_metadata_reader.dart';

// GPS como lo escribe una cámara: grados, minutos y segundos en racionales.
// image 4.10.1 no exporta la clase Rational, así que se arma la lista a partir
// de valores de un solo racional.
img.IfdValueRational _dms(int g, int m, int s100) {
  final v = img.IfdValueRational(g, 1);
  v.value
    ..add(img.IfdValueRational(m, 1).value.first)
    ..add(img.IfdValueRational(s100, 100).value.first);
  return v;
}

img.ExifData _exifSantiago() {
  final exif = img.ExifData();
  exif.exifIfd[0x9003] = img.IfdValueAscii('2026:11:05 14:30:00');
  exif.gpsIfd[0x0001] = img.IfdValueAscii('S');
  exif.gpsIfd[0x0002] = _dms(33, 26, 5600); // 33° 26' 56.00"
  exif.gpsIfd[0x0003] = img.IfdValueAscii('W');
  exif.gpsIfd[0x0004] = _dms(70, 41, 4900); // 70° 41' 49.00"
  return exif;
}

void main() {
  group('FotoMetadataReader (RF-11)', () {
    test('parsea la fecha EXIF como hora local', () {
      expect(
        FotoMetadataReader.parseFechaExif('2026:11:05 14:30:00'),
        DateTime(2026, 11, 5, 14, 30),
      );
    });

    test('fecha vacía o inválida -> null', () {
      expect(FotoMetadataReader.parseFechaExif('0000:00:00 00:00:00'), isNull);
      expect(FotoMetadataReader.parseFechaExif('ayer'), isNull);
    });

    test('usa DateTime (0x0132) si no hay DateTimeOriginal', () {
      final exif = img.ExifData();
      exif.imageIfd[0x0132] = img.IfdValueAscii('2026:10:01 08:00:00');
      expect(
        FotoMetadataReader.fechaDesdeExif(exif),
        DateTime(2026, 10, 1, 8),
      );
    });

    test('convierte GPS grados/min/seg a decimal con signo S/W', () {
      final c = FotoMetadataReader.coordenadasDesdeExif(_exifSantiago())!;
      expect(c.latitud, closeTo(-33.44889, 1e-4));
      expect(c.longitud, closeTo(-70.69694, 1e-4));
    });

    test('sin GPS o GPS en 0,0 -> null', () {
      expect(FotoMetadataReader.coordenadasDesdeExif(img.ExifData()), isNull);

      final cero = img.ExifData();
      cero.gpsIfd[0x0002] = _dms(0, 0, 0);
      cero.gpsIfd[0x0004] = _dms(0, 0, 0);
      expect(FotoMetadataReader.coordenadasDesdeExif(cero), isNull);
    });

    test('leer(): JPEG real con EXIF', () async {
      final dir = await Directory.systemTemp.createTemp('foto_meta');
      addTearDown(() => dir.delete(recursive: true));

      final image = img.Image(width: 16, height: 16)..exif = _exifSantiago();
      final file = File('${dir.path}/foto.jpg');
      await file.writeAsBytes(img.encodeJpg(image));

      final meta = await const FotoMetadataReader().leer(file.path);
      expect(meta.fechaDesdeExif, isTrue);
      expect(meta.fechaHora, DateTime(2026, 11, 5, 14, 30));
      expect(meta.coordenadas!.latitud, closeTo(-33.44889, 1e-4));
    });

    test('leer(): sin EXIF usa la fecha del archivo', () async {
      final dir = await Directory.systemTemp.createTemp('foto_meta');
      addTearDown(() => dir.delete(recursive: true));

      final file = File('${dir.path}/sin_exif.jpg');
      await file.writeAsBytes(img.encodeJpg(img.Image(width: 8, height: 8)));

      final meta = await const FotoMetadataReader().leer(file.path);
      expect(meta.fechaDesdeExif, isFalse);
      expect(meta.coordenadas, isNull);
      expect(meta.fechaHora, await file.lastModified());
    });
  });
}
