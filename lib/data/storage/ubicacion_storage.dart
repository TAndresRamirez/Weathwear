import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:weathwear/data/models/coordenadas.dart';

// Última ubicación conocida en un JSON en el almacenamiento de la app.
// El ETL en segundo plano la lee, porque desde ahí no se puede pedir GPS.
class UbicacionStorage {
  static const String _fileName = 'ubicacion.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Coordenadas?> leer() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return Coordenadas.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null; // archivo corrupto o ilegible: se trata como "sin dato"
    }
  }

  Future<void> guardar(Coordenadas c) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(c.toJson()), flush: true);
  }
}
