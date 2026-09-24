import 'package:weathwear/data/database/sqlite_helper.dart';
import 'package:weathwear/data/models/clima_model.dart';

class ClimaRepository {
  final SqliteHelper _dbHelper;

  // Recibe la instancia por parametro para inyectar un SqliteHelper de prueba en los tests de integracion
  ClimaRepository({SqliteHelper? dbHellper})
    : _dbHelper = dbHellper ?? SqliteHelper.instance;

  Future<int> insert(ClimaModel clima) async {
    final db = await _dbHelper.database;
    return db.insert('Clima', clima.toMap());
  }
}
