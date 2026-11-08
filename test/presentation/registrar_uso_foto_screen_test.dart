import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/coordenadas.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/photo/foto_metadata_reader.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/uso/obtener_clima_foto_use_case.dart';
import 'package:weathwear/domain/uso/registrar_uso_foto_use_case.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';
import 'package:weathwear/presentation/screens/registrar_uso_foto_screen.dart';

PrendaModel _p(int id, String tipo) => PrendaModel(
  idPrenda: id,
  tipo: tipo,
  imagenRuta: '/no/existe.jpg',
  tempMin: 15,
  tempMax: 25,
  condicionAplicable: 'despejado',
);

final _clima = ClimaFoto(
  clima: ClimaModel(
    idClima: 1,
    fechaHora: DateTime(2026, 11, 5, 14),
    temperatura: 21,
    humedad: 40,
    condicion: 'despejado',
  ),
  metadata: FotoMetadata(
    fechaHora: DateTime(2026, 11, 5, 14, 10),
    fechaDesdeExif: true,
  ),
  coordenadas: Coordenadas.santiago,
  origenUbicacion: OrigenUbicacion.guardada,
  reutilizado: false,
);

SlotPropuesta _slot(
  PrendaCategoria c,
  List<PrendaModel> candidatas, {
  ClassificationResult? det,
  bool proponer = true,
}) => SlotPropuesta(
  categoria: c,
  deteccion: det,
  candidatas: candidatas,
  propuesta: proponer && candidatas.isNotEmpty ? candidatas.first : null,
);

PropuestaUso _propuesta({
  List<PrendaModel> superiores = const [],
  bool esEntero = false,
}) => PropuestaUso(
  clima: _clima,
  esEntero: esEntero,
  slots: {
    PrendaCategoria.superior: _slot(
      PrendaCategoria.superior,
      superiores,
      det: const ClassificationResult(label: 'Polera', confidence: 0.9),
    ),
    PrendaCategoria.inferior: _slot(PrendaCategoria.inferior, [
      _p(2, 'Pantalon'),
      _p(3, 'Shorts'),
    ], det: const ClassificationResult(label: 'Pantalon', confidence: 0.5)),
    PrendaCategoria.entero: _slot(PrendaCategoria.entero, [_p(4, 'Entero')]),
    PrendaCategoria.exterior: _slot(PrendaCategoria.exterior, [
      _p(5, 'Chaqueta'),
    ], proponer: false),
  },
);

void main() {
  // Abre la pantalla desde un botón para poder leer el valor del pop
  Future<List<String?>> abrir(
    WidgetTester t, {
    required Future<PropuestaUso> Function(String) proponer,
    List<List<PrendaModel>>? registradas,
  }) async {
    // Pantalla alta: que todos los selectores queden construidos
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final resultados = <String?>[];
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultados.add(
                await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => RegistrarUsoFotoScreen(
                      pickImage: (_) async => '/no/existe.jpg',
                      proponer: proponer,
                      registrar: (clima, prendas) async {
                        registradas?.add(prendas);
                        return const RegistroUsoResultado(
                          7,
                          outfitNuevo: true,
                          usoRegistrado: true,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Galería'));
    await t.pumpAndSettle();
    return resultados;
  }

  testWidgets('muestra datos de la foto y registra lo propuesto', (t) async {
    final registradas = <List<PrendaModel>>[];
    final resultados = await abrir(
      t,
      proponer: (_) async => _propuesta(superiores: [_p(1, 'Polera')]),
      registradas: registradas,
    );

    expect(find.textContaining('05/11/2026 14:10'), findsOneWidget);
    expect(find.textContaining('última guardada'), findsOneWidget);
    expect(find.text('Detectado: Polera (90%)'), findsOneWidget);
    // Confianza 50% en la inferior: pide confirmar
    expect(find.textContaining('confírmala'), findsOneWidget);

    // El título del AppBar también dice "Registrar uso": se busca el botón
    await t.tap(find.widgetWithText(FilledButton, 'Registrar uso'));
    await t.pumpAndSettle();

    expect(registradas.single.map((p) => p.idPrenda), [1, 2]);
    expect(resultados.single, 'Uso registrado y outfit guardado');
  });

  testWidgets('sin prenda superior el botón queda deshabilitado', (t) async {
    await abrir(t, proponer: (_) async => _propuesta());

    final boton = find.widgetWithText(FilledButton, 'Registrar uso');
    expect(t.widget<FilledButton>(boton).onPressed, isNull);
  });

  testWidgets('modo entero registra la prenda entera', (t) async {
    final registradas = <List<PrendaModel>>[];
    await abrir(
      t,
      proponer: (_) async => _propuesta(esEntero: true),
      registradas: registradas,
    );

    expect(find.text('Prenda entera'), findsOneWidget);
    expect(find.text('Prenda superior'), findsNothing);

    await t.tap(find.widgetWithText(FilledButton, 'Registrar uso'));
    await t.pumpAndSettle();
    expect(registradas.single.map((p) => p.idPrenda), [4]);
  });

  testWidgets('error de clima se muestra sin botón de registrar', (t) async {
    await abrir(
      t,
      proponer: (_) async => throw const ClimaFotoException('sin conexión'),
    );

    expect(find.text('Clima: sin conexión'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Registrar uso'), findsNothing);
  });
}
