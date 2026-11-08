import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/coordenadas.dart';
import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/photo/foto_metadata_reader.dart';
import 'package:weathwear/data/repositories/clima_repository.dart';
import 'package:weathwear/data/repositories/outfit_repository.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/uso/obtener_clima_foto_use_case.dart';
import 'package:weathwear/domain/uso/registrar_uso_foto_use_case.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';

// Devuelve una detección por zona, en el orden superior, inferior, cuerpo
class _FakeClassifier implements ClothingClassifier {
  _FakeClassifier(this.porZona);
  final List<ClassificationResult> porZona;

  @override
  bool get isLoaded => true;
  @override
  Future<void> load() async {}
  @override
  Future<ClassificationResult> classify(String imagePath) async => porZona[0];
  @override
  Future<List<ClassificationResult>> classifyZonas(
    String imagePath,
    List<ZonaVertical> zonas,
  ) async => porZona;
  @override
  void dispose() {}
}

ClassificationResult _r(String label, [double conf = 0.9]) =>
    ClassificationResult(label: label, confidence: conf);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late PrendaRepository prendaRepo;
  late OutfitRepository outfitRepo;
  late ClimaFoto climaFoto;
  final fechaFoto = DateTime(2026, 11, 5, 14, 10);

  RegistrarUsoFotoUseCase crear(List<ClassificationResult> det) =>
      RegistrarUsoFotoUseCase(
        _FakeClassifier(det),
        prendaRepo: prendaRepo,
        outfitRepo: outfitRepo,
        obtenerClima: (_) async => climaFoto,
      );

  Future<PrendaModel> prenda(String tipo) async {
    final p = PrendaModel(
      tipo: tipo,
      imagenRuta: '/tmp/$tipo.jpg',
      tempMin: 5,
      tempMax: 25,
      condicionAplicable: 'despejado',
    );
    final id = await prendaRepo.insert(p);
    return (await prendaRepo.getById(id))!;
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE Clima (
        id_clima INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL, temperatura REAL NOT NULL,
        humedad REAL NOT NULL, condicion TEXT NOT NULL,
        sensacion_termica REAL, viento_kmh REAL)
    ''');
    await db.execute('''
      CREATE TABLE Prenda (
        id_prenda INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL, imagen_ruta TEXT NOT NULL,
        temp_min REAL NOT NULL, temp_max REAL NOT NULL,
        condicion_aplicable TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1)
    ''');
    await SqliteHelper.crearTablasOutfit(db);
    SqliteHelper.setTestDatabase(db);
    prendaRepo = PrendaRepository();
    outfitRepo = OutfitRepository();

    final clima = ClimaModel(
      fechaHora: DateTime(2026, 11, 5, 14),
      temperatura: 21,
      humedad: 40,
      condicion: 'despejado',
    );
    final idClima = await ClimaRepository().insert(clima);
    climaFoto = ClimaFoto(
      clima: clima.withId(idClima),
      metadata: FotoMetadata(fechaHora: fechaFoto, fechaDesdeExif: true),
      coordenadas: Coordenadas.santiago,
      origenUbicacion: OrigenUbicacion.foto,
      reutilizado: false,
    );
  });

  tearDown(() async {
    await db.close();
    SqliteHelper.resetForTest();
  });

  group('proponer (RF-10)', () {
    test('polera arriba y pantalón abajo: propone ambas, sin exterior', () async {
      final polera = await prenda('Polera');
      final pantalon = await prenda('Pantalon');
      await prenda('Shorts');

      final p = await crear([
        _r('Polera'),
        _r('Pantalon'),
        _r('Polera'),
      ]).proponer('foto.jpg');

      expect(p.esEntero, isFalse);
      expect(p.slots[PrendaCategoria.superior]!.propuesta!.idPrenda,
          polera.idPrenda);
      final inferior = p.slots[PrendaCategoria.inferior]!;
      expect(inferior.propuesta!.idPrenda, pantalon.idPrenda);
      expect(inferior.requiereConfirmacion, isFalse);
      expect(inferior.candidatas.length, 2); // el Shorts queda como alternativa
      expect(p.slots[PrendaCategoria.exterior]!.propuesta, isNull);
      expect(p.clima.clima.temperatura, 21);
    });

    test('mismo tipo: propone la prenda más usada', () async {
      final poleraA = await prenda('Polera');
      final poleraB = await prenda('Polera');
      final pantalon = await prenda('Pantalon');
      final idOutfit = await outfitRepo.insert(
        idsPrenda: [poleraA.idPrenda!, pantalon.idPrenda!],
      );
      await outfitRepo.registrarUso(
        idOutfit: idOutfit,
        idClima: climaFoto.clima.idClima!,
        fecha: DateTime(2026, 11, 1),
      );

      final p = await crear([
        _r('Polera'),
        _r('Pantalon'),
        _r('Polera'),
      ]).proponer('foto.jpg');

      // poleraB es más reciente, pero poleraA tiene un uso
      expect(p.slots[PrendaCategoria.superior]!.propuesta!.idPrenda,
          poleraA.idPrenda);
      expect(p.slots[PrendaCategoria.superior]!.candidatas.last.idPrenda,
          poleraB.idPrenda);
    });

    test('chaqueta arriba: exterior propuesto y superior por confirmar',
        () async {
      final chaqueta = await prenda('Chaqueta');
      await prenda('Polera');
      await prenda('Pantalon');

      final p = await crear([
        _r('Chaqueta'),
        _r('Pantalon'),
        _r('Chaqueta'),
      ]).proponer('foto.jpg');

      expect(p.slots[PrendaCategoria.exterior]!.propuesta!.idPrenda,
          chaqueta.idPrenda);
      final superior = p.slots[PrendaCategoria.superior]!;
      expect(superior.propuesta, isNotNull); // la más probable
      expect(superior.deteccion, isNull);
      expect(superior.requiereConfirmacion, isTrue);
    });

    test('entero con confianza suficiente activa el modo entero', () async {
      final vestido = await prenda('Entero');
      final p = await crear([
        _r('Entero'),
        _r('Shorts', 0.4),
        _r('Entero', 0.85),
      ]).proponer('foto.jpg');

      expect(p.esEntero, isTrue);
      expect(p.slots[PrendaCategoria.entero]!.propuesta!.idPrenda,
          vestido.idPrenda);
    });

    test('baja confianza: propone igual pero pide confirmación', () async {
      await prenda('Polera');
      await prenda('Pantalon');
      final p = await crear([
        _r('Polera', 0.5),
        _r('Pantalon'),
        _r('Polera', 0.5),
      ]).proponer('foto.jpg');

      expect(p.slots[PrendaCategoria.superior]!.requiereConfirmacion, isTrue);
    });

    test('sin prendas de la categoría: propuesta null', () async {
      final p = await crear([
        _r('Polera'),
        _r('Pantalon'),
        _r('Polera'),
      ]).proponer('foto.jpg');
      expect(p.slots[PrendaCategoria.superior]!.propuesta, isNull);
      expect(p.slots[PrendaCategoria.superior]!.candidatas, isEmpty);
    });
  });

  group('registrar (RF-10)', () {
    test('outfit nuevo: lo crea con origen foto y registra el uso '
        'con la fecha de la foto', () async {
      final polera = await prenda('Polera');
      final pantalon = await prenda('Pantalon');

      final r = await crear(const []).registrar(
        clima: climaFoto,
        prendas: [polera, pantalon],
      );

      expect(r.outfitNuevo, isTrue);
      expect(r.usoRegistrado, isTrue);
      final outfit = (await outfitRepo.getAll()).single;
      expect(outfit.origen, OutfitOrigen.foto);
      expect(outfit.vecesUsado, 1);
      expect(outfit.ultimoUso, fechaFoto);
    });

    test('outfit existente: lo reutiliza', () async {
      final polera = await prenda('Polera');
      final pantalon = await prenda('Pantalon');
      final id = await outfitRepo.insert(
        idsPrenda: [polera.idPrenda!, pantalon.idPrenda!],
      );

      final r = await crear(const []).registrar(
        clima: climaFoto,
        prendas: [pantalon, polera],
      );
      expect(r.idOutfit, id);
      expect(r.outfitNuevo, isFalse);
      expect((await outfitRepo.getAll()).length, 1);
    });

    test('mismo outfit y mismo día: no duplica el uso', () async {
      final polera = await prenda('Polera');
      final pantalon = await prenda('Pantalon');
      final uc = crear(const []);
      await uc.registrar(clima: climaFoto, prendas: [polera, pantalon]);
      final r = await uc.registrar(
        clima: climaFoto,
        prendas: [polera, pantalon],
      );
      expect(r.usoRegistrado, isFalse);
    });

    test('composición inválida -> OutfitException', () async {
      final polera = await prenda('Polera');
      expect(
        () => crear(const []).registrar(clima: climaFoto, prendas: [polera]),
        throwsA(isA<OutfitException>()),
      );
    });
  });
}
