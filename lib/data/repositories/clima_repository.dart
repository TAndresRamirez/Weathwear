import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';

class ClimaRepository {
  final SqliteHelper _dbHelper;

  // Recibe la instancia por parametro para inyectar un SqliteHelper de prueba en los tests de integracion
  ClimaRepository({SqliteHelper? dbHelper})
    : _dbHelper = dbHelper ?? SqliteHelper.instance;

  Future<int> insert(ClimaModel clima) async {
    final db = await _dbHelper.database;
    return db.insert('Clima', clima.toMap());
  }

  Future<ClimaModel?> getUltimo() async {
    final db = await _dbHelper.database;
    final rows = await db.query('Clima', orderBy: 'fecha_hora DESC', limit: 1);
    return rows.isEmpty ? null : ClimaModel.fromMap(rows.first);
  }

  /// Registro más cercano a [fecha] dentro de ±[tolerancia], o null.
  /// Sirve para reutilizar lo que ya guardó el ETL horario en vez de volver
  /// a consultar la API (RF-11).
  Future<ClimaModel?> buscarCercano(
    DateTime fecha, {
    Duration tolerancia = const Duration(minutes: 30),
  }) async {
    final db = await _dbHelper.database;
    // fecha_hora es ISO 8601 local: el orden de texto coincide con el temporal
    final rows = await db.query(
      'Clima',
      where: 'fecha_hora BETWEEN ? AND ?',
      whereArgs: [
        fecha.subtract(tolerancia).toIso8601String(),
        fecha.add(tolerancia).toIso8601String(),
      ],
    );
    if (rows.isEmpty) return null;

    final candidatos = rows.map(ClimaModel.fromMap).toList()
      ..sort(
        (a, b) => a.fechaHora
            .difference(fecha)
            .abs()
            .compareTo(b.fechaHora.difference(fecha).abs()),
      );
    return candidatos.first;
  }
}
