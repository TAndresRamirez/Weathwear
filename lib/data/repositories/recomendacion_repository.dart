import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';

class RecomendacionRepository {
  final SqliteHelper _dbHelper;

  RecomendacionRepository({SqliteHelper? dbHelper})
    : _dbHelper = dbHelper ?? SqliteHelper.instance;

  // Un Outfit = 2-3 filas (una por prenda) con el mismo fecha_generacion
  // La transaccion garantiza que se guarda completo o nada
  Future<void> insertOutfit({
    required int idClima,
    required Outfit outfit,
    DateTime? fecha,
  }) async {
    final db = await _dbHelper.database;
    final ts = (fecha ?? DateTime.now()).toIso8601String();

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final p in outfit.prendas) {
        batch.insert('Recomendacion', {
          'id_clima': idClima,
          'id_prenda': p.idPrenda,
          'fecha_generacion': ts,
          'nivel_similitud': outfit.similitud,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // Ids de prenda del ultimo outfit generado para ese clima (vacio si no hay)
  // fecha_generacion es ISO 8601, asi que MAX() ordena bien como texto
  Future<Set<int>> idsUltimoOutfit(int idClima) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT id_prenda FROM Recomendacion
      WHERE id_clima = ? AND fecha_generacion = (
        SELECT MAX(fecha_generacion) FROM Recomendacion WHERE id_clima = ?)
      ''',
      [idClima, idClima],
    );
    return rows.map((r) => r['id_prenda'] as int).toSet();
  }
}
