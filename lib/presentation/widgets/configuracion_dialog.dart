import 'package:flutter/material.dart';
import 'package:weathwear/core/utils/compartir_archivo.dart';
import 'package:weathwear/data/models/ajustes.dart';
import 'package:weathwear/data/storage/respaldo_service.dart';
import 'package:weathwear/domain/settings/ajustes_controller.dart';

/// Pop-up de configuración, común a las 3 pestañas.
/// Secciones: Tema, Ubicación, Personalización, Archivos e Idioma.
class ConfiguracionDialog extends StatelessWidget {
  const ConfiguracionDialog({
    super.key,
    this.controller,
    this.respaldo,
    this.compartir,
  });

  /// Inyectables para tests. Si son null usa los reales.
  final AjustesController? controller;
  final RespaldoService? respaldo;
  final Future<void> Function(String path)? compartir;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? AjustesController.instance;
    final text = Theme.of(context).textTheme;

    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        // Cada cambio se refleja al instante dentro del propio diálogo
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final a = c.ajustes;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Configuración', style: text.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // --- Tema ---
                _Selector<ThemeMode>(
                  titulo: 'Tema',
                  valor: a.tema,
                  opciones: const {
                    ThemeMode.light: 'Claro',
                    ThemeMode.dark: 'Oscuro',
                    ThemeMode.system: 'Sistema',
                  },
                  onChanged: (v) => c.actualizar(a.copyWith(tema: v)),
                ),
                const SizedBox(height: 8),

                // --- Ubicación ---
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usar GPS'),
                  subtitle: const Text(
                    'Si lo desactivas, se usará la última ubicación guardada.',
                  ),
                  value: a.usarGps,
                  onChanged: (v) => c.actualizar(a.copyWith(usarGps: v)),
                ),
                const Divider(),

                // --- Personalización ---
                Text('Personalización', style: text.titleMedium),
                const SizedBox(height: 12),
                _Selector<FormatoFecha>(
                  titulo: 'Formato de fecha',
                  valor: a.formatoFecha,
                  opciones: const {
                    FormatoFecha.diaMesAnio: 'dd/mm/aaaa',
                    FormatoFecha.mesDiaAnio: 'mm/dd/aaaa',
                  },
                  onChanged: (v) => c.actualizar(a.copyWith(formatoFecha: v)),
                ),
                const SizedBox(height: 12),
                _Selector<VistaInicial>(
                  titulo: 'Al abrir la app, mostrar',
                  valor: a.vistaInicial,
                  opciones: const {
                    VistaInicial.hoy1: 'Clima',
                    VistaInicial.hoy2: 'Sugerencia',
                  },
                  onChanged: (v) => c.actualizar(a.copyWith(vistaInicial: v)),
                ),
                const SizedBox(height: 12),
                _Selector<UnidadTemperatura>(
                  titulo: 'Temperatura',
                  valor: a.unidadTemperatura,
                  opciones: const {
                    UnidadTemperatura.celsius: '°C',
                    UnidadTemperatura.fahrenheit: '°F',
                  },
                  onChanged: (v) =>
                      c.actualizar(a.copyWith(unidadTemperatura: v)),
                ),
                const SizedBox(height: 12),
                _Selector<UnidadViento>(
                  titulo: 'Viento',
                  valor: a.unidadViento,
                  opciones: const {
                    UnidadViento.kmh: 'km/h',
                    UnidadViento.mph: 'mph',
                  },
                  onChanged: (v) => c.actualizar(a.copyWith(unidadViento: v)),
                ),
                const Divider(),

                // --- Archivos ---
                Text('Archivos', style: text.titleMedium),
                const SizedBox(height: 4),
                _SeccionArchivos(respaldo: respaldo, compartir: compartir),
                const Divider(),

                // --- Idioma ---
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Idioma'),
                  subtitle: const Text('Español'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Idioma'),
                      content: const Text('Función en proceso.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Título + selector segmentado de una sola opción. Evita repetir el mismo
/// bloque para cada ajuste.
class _Selector<T> extends StatelessWidget {
  const _Selector({
    required this.titulo,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final String titulo;
  final T valor;
  final Map<T, String> opciones;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<T>(
          showSelectedIcon: false, // ahorra ancho en pantallas chicas
          segments: [
            for (final e in opciones.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {valor},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

/// Respaldo de la BD y ubicación de los datos. Tiene estado propio (ocupado y
/// error) para que el diálogo principal siga siendo StatelessWidget.
/// El error se muestra en línea: un SnackBar quedaría detrás del diálogo.
class _SeccionArchivos extends StatefulWidget {
  const _SeccionArchivos({this.respaldo, this.compartir});

  final RespaldoService? respaldo;
  final Future<void> Function(String path)? compartir;

  @override
  State<_SeccionArchivos> createState() => _SeccionArchivosState();
}

class _SeccionArchivosState extends State<_SeccionArchivos> {
  late final RespaldoService _respaldo = widget.respaldo ?? RespaldoService();
  bool _ocupado = false;
  String? _error;

  Future<void> _respaldar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final archivo = await _respaldo.crearCopia();
      await (widget.compartir ?? compartirArchivo)(archivo.path);
    } catch (e) {
      debugPrint('Error al crear el respaldo: $e');
      if (mounted) setState(() => _error = 'No se pudo crear el respaldo');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _verUbicacion() async {
    String ruta;
    try {
      ruta = await _respaldo.rutaBd();
    } catch (_) {
      ruta = 'No disponible';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación de los datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(ruta),
            const SizedBox(height: 12),
            const Text(
              'Es almacenamiento privado de la app: no se ve desde el '
              'explorador de archivos. Usa "Respaldar datos" para sacar una copia.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.ios_share),
          title: const Text('Respaldar datos'),
          subtitle: const Text('Comparte una copia de la base de datos'),
          trailing: _ocupado
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _ocupado ? null : _respaldar,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Ubicación de los datos'),
          onTap: _verUbicacion,
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
