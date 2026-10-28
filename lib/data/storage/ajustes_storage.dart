import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:weathwear/data/models/ajustes.dart';

/// Ajustes en un JSON en el almacenamiento de la app (mismo patrón que
/// UbicacionStorage). Evita sumar una dependencia para 6 valores.
class AjustesStorage {
  static const String _fileName = 'ajustes.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Nunca lanza: sin archivo o con archivo corrupto devuelve los defaults.
  Future<Ajustes> leer() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const Ajustes();
      final json = jsonDecode(await file.readAsString());
      return Ajustes.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return const Ajustes();
    }
  }

  Future<void> guardar(Ajustes ajustes) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(ajustes.toJson()), flush: true);
  }
}
