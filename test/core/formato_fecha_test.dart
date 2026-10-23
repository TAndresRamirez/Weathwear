import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/core/utils/formato_fecha.dart';

void main() {
  final hoy = DateTime(2026, 10, 23, 15);

  test('etiquetaDia: hoy, ayer y fechas anteriores', () {
    expect(etiquetaDia(DateTime(2026, 10, 23, 8), hoy: hoy), 'Hoy');
    expect(etiquetaDia(DateTime(2026, 10, 22, 23, 59), hoy: hoy), 'Ayer');
    expect(etiquetaDia(DateTime(2026, 10, 19, 10), hoy: hoy), '19/10/2026');
  });

  test('etiquetaDia: "Ayer" se mantiene cruzando un cambio de mes', () {
    final primeroDeMes = DateTime(2026, 11, 1, 9);
    expect(etiquetaDia(DateTime(2026, 10, 31, 22), hoy: primeroDeMes), 'Ayer');
  });

  test('etiquetaCabecera: día de la semana y número', () {
    expect(etiquetaCabecera(DateTime(2026, 10, 23)), 'Viernes 23');
  });
}
