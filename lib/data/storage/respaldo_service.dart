import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:weathwear/data/database/sqlite_helper.dart';

/// Crea una copia consistente de la BD lista para compartir.
class RespaldoService {
  RespaldoService({
    SqliteHelper? dbHelper,
    Future<Directory> Function()? carpetaTemporal,
    DateTime Function()? now,
  }) : _dbHelper = dbHelper ?? SqliteHelper.instance,
       _carpetaTemporal = carpetaTemporal ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  static const String _carpeta = 'respaldos';
  static const String _prefijo = 'weathwear_respaldo_';

  final SqliteHelper _dbHelper;
  final Future<Directory> Function() _carpetaTemporal; // inyectable para tests
  final DateTime Function() _now;

  /// Ruta real del archivo .db (para mostrarla al usuario).
  Future<String> rutaBd() async => (await _dbHelper.database).path;

  /// Copia la BD a la carpeta temporal y devuelve el archivo.
  Future<File> crearCopia() async {
    final db = await _dbHelper.database;

    // Pasa al archivo principal lo pendiente en el WAL (si lo hay), para que
    // la copia no quede desfasada. Sin WAL, no hace nada.
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

    final base = await _carpetaTemporal();
    final dir = Directory(p.join(base.path, _carpeta));
    // Solo se conserva el último respaldo: no se acumulan copias en la caché.
    // No se borra tras compartir: la app destino puede leer el archivo después.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    return File(db.path)
        .copy(p.join(dir.path, '$_prefijo${_sello(_now())}.db'));
  }

  String _sello(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${dos(d.month)}${dos(d.day)}_${dos(d.hour)}${dos(d.minute)}';
  }
}
