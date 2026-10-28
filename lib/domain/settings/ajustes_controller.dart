import 'package:flutter/foundation.dart';
import 'package:weathwear/data/models/ajustes.dart';
import 'package:weathwear/data/storage/ajustes_storage.dart';

/// Estado global de los ajustes. Las pantallas escuchan con
/// ListenableBuilder y cambian valores con [actualizar].
class AjustesController extends ChangeNotifier {
  AjustesController({AjustesStorage? storage})
    : _storage = storage ?? AjustesStorage();

  /// Instancia compartida de la app (los tests crean la suya).
  static final AjustesController instance = AjustesController();

  final AjustesStorage _storage;
  Ajustes _ajustes = const Ajustes();

  Ajustes get ajustes => _ajustes;

  Future<void> cargar() async {
    _ajustes = await _storage.leer();
    notifyListeners();
  }

  /// Actualiza en memoria primero (la UI responde al instante) y persiste después.
  Future<void> actualizar(Ajustes nuevos) async {
    _ajustes = nuevos;
    notifyListeners();
    try {
      await _storage.guardar(nuevos);
    } catch (e) {
      debugPrint('No se pudieron guardar los ajustes: $e');
    }
  }
}
