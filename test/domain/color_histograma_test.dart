import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:weathwear/domain/vision/color_histograma.dart';

img.Image _lisa(int r, int g, int b) =>
    img.Image(width: 40, height: 40)..clear(img.ColorRgb8(r, g, b));

void main() {
  group('ColorHistograma (RF-10)', () {
    test('histograma normalizado (suma 1)', () {
      final h = ColorHistograma.deImagen(_lisa(200, 30, 30));
      expect(h.length, ColorHistograma.longitud);
      expect(h.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('mismo color -> similitud 1', () {
      final a = ColorHistograma.deImagen(_lisa(200, 30, 30));
      final b = ColorHistograma.deImagen(_lisa(205, 35, 28));
      expect(ColorHistograma.similitud(a, b), closeTo(1, 1e-9));
    });

    test('rojo vs azul -> similitud 0', () {
      final rojo = ColorHistograma.deImagen(_lisa(200, 30, 30));
      final azul = ColorHistograma.deImagen(_lisa(30, 30, 200));
      expect(ColorHistograma.similitud(rojo, azul), 0);
    });

    test('negro y blanco caen en bins de gris distintos', () {
      final negro = ColorHistograma.deImagen(_lisa(10, 10, 10));
      final blanco = ColorHistograma.deImagen(_lisa(245, 245, 245));
      expect(ColorHistograma.similitud(negro, blanco), 0);
    });

    test('ignora los bordes (fondo) según el margen', () {
      // Centro rojo, borde azul de 8 px: con margen 0.2 solo se ve el rojo
      final imagen = _lisa(30, 30, 200);
      img.fillRect(
        imagen,
        x1: 8,
        y1: 8,
        x2: 32,
        y2: 32,
        color: img.ColorRgb8(200, 30, 30),
      );
      final centro = ColorHistograma.deImagen(imagen);
      final rojo = ColorHistograma.deImagen(_lisa(200, 30, 30));
      expect(ColorHistograma.similitud(centro, rojo), closeTo(1, 1e-9));
    });

    test('histograma vacío o de otro largo -> similitud 0', () {
      final rojo = ColorHistograma.deImagen(_lisa(200, 30, 30));
      expect(ColorHistograma.similitud(rojo, const []), 0);
    });
  });
}
