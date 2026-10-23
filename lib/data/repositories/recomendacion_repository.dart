import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/domain/recommendation/outfit.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/models/historial_entry.dart';

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

  // Un registro por día: el último outfit generado ese día.
  // [dias] limita la cantidad de días devueltos (no de outfits).
  Future<List<HistorialEntry>> getHistorial({int dias = 30}) async {
    final db = await _dbHelper.database;
    // fecha_generacion es ISO 8601 en hora local: los primeros 10 caracteres
    // son el día, y MAX() sobre el texto da el outfit más reciente de ese día.
    final rows = await db.rawQuery(
      '''
      SELECT r.fecha_generacion, r.nivel_similitud,
             c.id_clima, c.fecha_hora, c.temperatura, c.humedad, c.condicion,
             c.sensacion_termica, c.viento_kmh,
             p.id_prenda, p.tipo, p.imagen_ruta, p.temp_min, p.temp_max,
             p.condicion_aplicable
      FROM Recomendacion r
      JOIN Clima  c ON c.id_clima  = r.id_clima
      JOIN Prenda p ON p.id_prenda = r.id_prenda
      WHERE r.fecha_generacion IN (
        SELECT MAX(fecha_generacion) FROM Recomendacion
        GROUP BY substr(fecha_generacion, 1, 10)
        ORDER BY MAX(fecha_generacion) DESC
        LIMIT ?)
      ORDER BY r.fecha_generacion DESC, r.id_recomendacion ASC
      ''',
      [dias],
    );

    // El literal {} de Dart conserva el orden de inserción
    final porOutfit = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      porOutfit.putIfAbsent(r['fecha_generacion'] as String, () => []).add(r);
    }

    return porOutfit.entries.map((e) {
      final primera = e.value.first;
      return HistorialEntry(
        clima: ClimaModel.fromMap(primera),
        fechaGeneracion: DateTime.parse(e.key),
        similitud: (primera['nivel_similitud'] as num?)?.toDouble() ?? 0,
        prendas: e.value.map(PrendaModel.fromMap).toList(),
      );
    }).toList();
  }
}
