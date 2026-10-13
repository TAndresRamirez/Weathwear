import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';

class PrendaRepository {
  final SqliteHelper _dbHelper;

  // Inyectable para usar una BD en memoriaen los test
  PrendaRepository({SqliteHelper? dbHelper})
    : _dbHelper = dbHelper ?? SqliteHelper.instance;

  // Inserta una prenda y retorna su id_prenda autogenerado
  Future<int> insert(PrendaModel prenda) async {
    final db = await _dbHelper.database;
    return db.insert('Prenda', prenda.toMap());
  }

  Future<PrendaModel?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'Prenda',
      where: 'id_prenda = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PrendaModel.fromMap(rows.first);
  }

  Future<List<PrendaModel>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'Prenda',
      where: 'activa = 1',
      orderBy: 'id_prenda DESC',
    );
    return rows.map(PrendaModel.fromMap).toList();
  }

  // La categoria se deriva de 'tipo' en codigo (no existe en la BD), asi que se filtra en Dart
  Future<List<PrendaModel>> getByCategoria(PrendaCategoria categoria) async {
    final todas = await getAll();
    return todas.where((p) => p.categoria == categoria).toList();
  }

  // Para la correccion manual del usuario cuando el clasificador se equivoca
  Future<int> update(PrendaModel prenda) async {
    if (prenda.idPrenda == null) {
      throw ArgumentError('No se puede actualizar una prenda sin idPrenda');
    }
    final db = await _dbHelper.database;
    return db.update(
      'Prenda',
      prenda.toMap(),
      where: 'id_prenda = ?',
      whereArgs: [prenda.idPrenda],
    );
  }

  Future<int> desactivar(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      'Prenda',
      {'activa': 0},
      where: 'id_prenda = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.delete('Prenda', where: 'id_prenda = ?', whereArgs: [id]);
  }
}
