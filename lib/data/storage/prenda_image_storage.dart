import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Copia las fotos al almacenamiento permanenet de la app
// La ruta que entrega image_picker es cache y Android puede borrarla
class PrendaImageStorage {
  static const String _folder = 'prendas';

  // Copia "sourcePath" a <documents>/prendas/ y retorna la nueva ruta
  Future<String> save(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);

    // Timestamp en microsegundos, con nombre unico sin depender del original
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(sourcePath)}';
    final saved = await File(sourcePath).copy(p.join(dir.path, fileName));
    return saved.path;
  }

  //Elimina una foto ya guardada (rollback si falla el insert en DB)
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
