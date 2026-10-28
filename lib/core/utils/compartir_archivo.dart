import 'package:share_plus/share_plus.dart';

/// Abre el selector de compartir del sistema (WhatsApp, Drive, correo...).
/// Es el único punto que toca share_plus: si cambia su API, se corrige aquí.
Future<void> compartirArchivo(String path, {String? asunto}) async {
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], subject: asunto),
  );
}
