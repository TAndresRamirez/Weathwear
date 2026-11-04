import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/outfit_guardado.dart';
import 'package:weathwear/data/models/prenda_model.dart';

class OutfitRepository {
  final SqliteHelper _dbHelper;

  OutfitRepository({SqliteHelper? dbHelper})
    : _dbHelper = dbHelper ?? SqliteHelper.instance;

  // Outfit + sus prendas en una transacción: se guarda completo o nada
  Future<int> insert({
    required List<int> idsPrenda,
    String origen = OutfitOrigen.manual,
    DateTime? fecha,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final id = await txn.insert('Outfit', {
        'fecha_creacion': (fecha ?? DateTime.now()).toIso8601String(),
        'origen': origen,
      });
      final batch = txn.batch();
      for (final idPrenda in idsPrenda) {
        batch.insert('OutfitPrenda', {'id_outfit': id, 'id_prenda': idPrenda});
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  /// Id del outfit cuyo conjunto de prendas es exactamente [idsPrenda]
  /// (sin importar el orden), o null si no existe.
  Future<int?> buscarIdPorPrendas(Set<int> idsPrenda) async {
    if (idsPrenda.isEmpty) return null;
    final db = await _dbHelper.database;
    final marcas = List.filled(idsPrenda.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT id_outfit FROM OutfitPrenda
      GROUP BY id_outfit
      HAVING COUNT(*) = ?
         AND SUM(CASE WHEN id_prenda IN ($marcas) THEN 1 ELSE 0 END) = ?
      LIMIT 1
      ''',
      [idsPrenda.length, ...idsPrenda, idsPrenda.length],
    );
    return rows.isEmpty ? null : rows.first['id_outfit'] as int;
  }

  /// Todos los outfits, del más reciente al más antiguo. Un outfit con alguna
  /// prenda desactivada queda oculto (se filtra y ordena luego con OutfitFiltro).
  Future<List<OutfitGuardado>> getAll() async {
    final db = await _dbHelper.database;

    final outfits = await db.rawQuery('''
      SELECT o.id_outfit, o.fecha_creacion, o.origen,
        (SELECT COUNT(*) FROM OutfitUso u
          WHERE u.id_outfit = o.id_outfit) AS veces_usado,
        (SELECT AVG(c.temperatura) FROM OutfitUso u
          JOIN Clima c ON c.id_clima = u.id_clima
          WHERE u.id_outfit = o.id_outfit) AS temp_promedio_uso,
        (SELECT MAX(u.fecha_uso) FROM OutfitUso u
          WHERE u.id_outfit = o.id_outfit) AS ultimo_uso
      FROM Outfit o
      ORDER BY o.fecha_creacion DESC, o.id_outfit DESC
    ''');

    final filas = await db.rawQuery('''
      SELECT op.id_outfit, p.*
      FROM OutfitPrenda op
      JOIN Prenda p ON p.id_prenda = op.id_prenda
    ''');
    final porOutfit = <int, List<Map<String, Object?>>>{};
    for (final f in filas) {
      porOutfit.putIfAbsent(f['id_outfit'] as int, () => []).add(f);
    }

    final resultado = <OutfitGuardado>[];
    for (final o in outfits) {
      final id = o['id_outfit'] as int;
      final filasPrenda = porOutfit[id] ?? const [];
      if (filasPrenda.isEmpty || filasPrenda.any((f) => f['activa'] == 0)) {
        continue;
      }
      final prendas = filasPrenda.map(PrendaModel.fromMap).toList()
        ..sort((a, b) => a.categoria.index.compareTo(b.categoria.index));
      // Composición inválida (datos antiguos): se oculta en vez de romper la pantalla
      if (!OutfitGuardado.composicionValida(prendas)) continue;
      final ultimo = o['ultimo_uso'] as String?;
      resultado.add(
        OutfitGuardado(
          idOutfit: id,
          fechaCreacion: DateTime.parse(o['fecha_creacion'] as String),
          origen: o['origen'] as String,
          prendas: prendas,
          vecesUsado: o['veces_usado'] as int,
          tempPromedioUso: (o['temp_promedio_uso'] as num?)?.toDouble(),
          ultimoUso: ultimo == null ? null : DateTime.parse(ultimo),
        ),
      );
    }
    return resultado;
  }

  /// Un uso por outfit y día (evita contar doble si se toca dos veces).
  /// Retorna false si hoy ya estaba registrado.
  Future<bool> registrarUso({
    required int idOutfit,
    required int idClima,
    DateTime? fecha,
  }) async {
    final db = await _dbHelper.database;
    final ts = (fecha ?? DateTime.now()).toIso8601String();
    // fecha_uso es ISO 8601 local: los primeros 10 caracteres son el día
    final dia = ts.substring(0, 10);

    return db.transaction((txn) async {
      final existente = await txn.rawQuery(
        'SELECT 1 FROM OutfitUso '
        'WHERE id_outfit = ? AND substr(fecha_uso, 1, 10) = ? LIMIT 1',
        [idOutfit, dia],
      );
      if (existente.isNotEmpty) return false;
      await txn.insert('OutfitUso', {
        'id_outfit': idOutfit,
        'id_clima': idClima,
        'fecha_uso': ts,
      });
      return true;
    });
  }

  // ON DELETE CASCADE borra también sus prendas asociadas y sus usos
  Future<int> eliminar(int idOutfit) async {
    final db = await _dbHelper.database;
    return db.delete('Outfit', where: 'id_outfit = ?', whereArgs: [idOutfit]);
  }
}
