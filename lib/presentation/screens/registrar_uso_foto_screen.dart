import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/core/utils/formato_fecha.dart';
import 'package:weathwear/core/utils/formato_unidades.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/domain/outfits/guardar_outfit_use_case.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/settings/ajustes_controller.dart';
import 'package:weathwear/domain/uso/obtener_clima_foto_use_case.dart';
import 'package:weathwear/domain/uso/registrar_uso_foto_use_case.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';
import 'package:weathwear/presentation/widgets/app_background.dart';
import 'package:weathwear/presentation/widgets/prenda_selector.dart';

/// RF-10 + RF-11: foto puesta -> prendas propuestas + clima de ese momento ->
/// confirmar/corregir -> uso registrado.
/// Hace pop(String) con el mensaje para el SnackBar si se registró.
class RegistrarUsoFotoScreen extends StatefulWidget {
  const RegistrarUsoFotoScreen({
    super.key,
    this.proponer,
    this.registrar,
    this.pickImage,
  });

  /// Inyectables para tests. Si son null se usa RegistrarUsoFotoUseCase real.
  final Future<PropuestaUso> Function(String path)? proponer;
  final Future<RegistroUsoResultado> Function(
    ClimaFoto clima,
    List<PrendaModel> prendas,
  )?
  registrar;
  final Future<String?> Function(ImageSource source)? pickImage;

  @override
  State<RegistrarUsoFotoScreen> createState() => _RegistrarUsoFotoScreenState();
}

class _RegistrarUsoFotoScreenState extends State<RegistrarUsoFotoScreen> {
  ClothingClassifier?
  _classifier; // solo si lo creamos nosotros (hay que cerrarlo)
  RegistrarUsoFotoUseCase? _useCase;

  String? _path;
  bool _picking = false;
  bool _analizando = false;
  bool _guardando = false;
  String? _error;
  PropuestaUso? _propuesta;

  bool _modoEntero = false;
  final Map<PrendaCategoria, PrendaModel?> _seleccion = {};

  @override
  void initState() {
    super.initState();
    if (widget.proponer == null || widget.registrar == null) {
      _classifier = ClothingClassifier();
      _useCase = RegistrarUsoFotoUseCase(_classifier!);
    }
  }

  @override
  void dispose() {
    _classifier?.dispose(); // libera el Interpreter de TFLite
    super.dispose();
  }

  Future<String?> _pick(ImageSource source) async {
    if (widget.pickImage != null) return widget.pickImage!(source);
    // Sin maxWidth/maxHeight: al redimensionar, image_picker reescribe el
    // archivo y puede perder parte del EXIF (fecha/GPS) que necesita el RF-11.
    // El costo de decodificar 12 MP lo absorbe el isolate del clasificador.
    final photo = await ImagePicker().pickImage(source: source);
    return photo?.path;
  }

  Future<void> _elegir(ImageSource source) async {
    setState(() => _picking = true);
    final String? path;
    try {
      path = await _pick(source);
    } catch (_) {
      if (!mounted) return;
      setState(() => _picking = false);
      _snack('No se pudo abrir la cámara o la galería');
      return;
    }
    if (!mounted) return;
    if (path == null) {
      setState(() => _picking = false); // cancelado: se queda donde estaba
      return;
    }

    setState(() {
      _path = path;
      _picking = false;
      _analizando = true;
      _error = null;
      _propuesta = null;
    });

    try {
      final propuesta = await (widget.proponer ?? _useCase!.proponer)(path);
      if (!mounted) return;
      setState(() {
        _propuesta = propuesta;
        _modoEntero = propuesta.esEntero;
        _seleccion
          ..clear()
          ..addAll({
            for (final e in propuesta.slots.entries) e.key: e.value.propuesta,
          });
      });
    } on ClimaFotoException catch (e) {
      if (mounted) setState(() => _error = 'Clima: ${e.message}');
    } on ClassifierException {
      if (mounted) setState(() => _error = 'No se pudo analizar la foto.');
    } catch (e) {
      debugPrint('Error proponiendo uso desde foto: $e');
      if (mounted) setState(() => _error = 'No se pudo procesar la foto.');
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  // Prendas elegidas según el modo; null-aware elements omiten las vacías
  List<PrendaModel> get _prendasElegidas => _modoEntero
      ? [
          ?_seleccion[PrendaCategoria.entero],
          ?_seleccion[PrendaCategoria.exterior],
        ]
      : [
          ?_seleccion[PrendaCategoria.superior],
          ?_seleccion[PrendaCategoria.inferior],
          ?_seleccion[PrendaCategoria.exterior],
        ];

  bool get _completo => _modoEntero
      ? _seleccion[PrendaCategoria.entero] != null
      : _seleccion[PrendaCategoria.superior] != null &&
            _seleccion[PrendaCategoria.inferior] != null;

  Future<void> _guardar() async {
    final propuesta = _propuesta!;
    setState(() => _guardando = true);
    try {
      final r = await (widget.registrar ?? _registrarReal)(
        propuesta.clima,
        _prendasElegidas,
      );
      if (!mounted) return;
      final mensaje = !r.usoRegistrado
          ? 'Ese outfit ya tenía un uso registrado ese día'
          : r.outfitNuevo
          ? 'Uso registrado y outfit guardado'
          : 'Uso registrado';
      Navigator.of(context).pop(mensaje);
    } on OutfitException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo registrar el uso');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<RegistroUsoResultado> _registrarReal(
    ClimaFoto clima,
    List<PrendaModel> prendas,
  ) => _useCase!.registrar(clima: clima, prendas: prendas);

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Registrar uso'),
          backgroundColor: Colors.transparent,
        ),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_picking) return const Center(child: CircularProgressIndicator());
    if (_path == null) return _ElegirFoto(onElegir: _elegir);

    final propuesta = _propuesta;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: Image.file(
                  File(_path!),
                  fit: BoxFit.contain,
                  // Decodifica a tamaño de pantalla, no los 12 MP originales
                  cacheHeight: 660,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _analizando || _guardando
                    ? null
                    : () => setState(() {
                        _path = null;
                        _propuesta = null;
                        _error = null;
                      }),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Cambiar foto'),
              ),
              const SizedBox(height: 8),
              if (_analizando)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Analizando foto y clima...'),
                  ],
                )
              else if (_error != null)
                Text(_error!, textAlign: TextAlign.center)
              else if (propuesta != null) ...[
                _DatosFoto(clima: propuesta.clima),
                const SizedBox(height: 16),
                ..._selectores(propuesta),
              ],
            ],
          ),
        ),
        if (propuesta != null && !_analizando)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _completo && !_guardando ? _guardar : null,
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar uso'),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _selectores(PropuestaUso p) {
    final slots = p.slots;
    // El modo entero solo se ofrece si el usuario tiene prendas enteras
    final hayEnteros = slots[PrendaCategoria.entero]!.candidatas.isNotEmpty;

    Widget selector(String titulo, PrendaCategoria c, {bool opcional = false}) {
      final slot = slots[c]!;
      return PrendaSelector(
        titulo: titulo,
        subtitulo: _EstadoSlot(slot: slot, opcional: opcional),
        prendas: slot.candidatas,
        seleccionada: _seleccion[c],
        onTap: (prenda) => setState(() {
          // Tocar la seleccionada la deselecciona
          _seleccion[c] = _seleccion[c]?.idPrenda == prenda.idPrenda
              ? null
              : prenda;
        }),
      );
    }

    return [
      if (hayEnteros) ...[
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Superior + inferior')),
            ButtonSegment(value: true, label: Text('Entero')),
          ],
          selected: {_modoEntero},
          onSelectionChanged: (s) => setState(() => _modoEntero = s.first),
        ),
        const SizedBox(height: 16),
      ],
      if (_modoEntero)
        selector('Prenda entera', PrendaCategoria.entero)
      else ...[
        selector('Prenda superior', PrendaCategoria.superior),
        const SizedBox(height: 16),
        selector('Prenda inferior', PrendaCategoria.inferior),
      ],
      const SizedBox(height: 16),
      selector(
        'Prenda exterior (opcional)',
        PrendaCategoria.exterior,
        opcional: true,
      ),
    ];
  }
}

/// Botones iniciales cuando aún no hay foto.
class _ElegirFoto extends StatelessWidget {
  const _ElegirFoto({required this.onElegir});
  final ValueChanged<ImageSource> onElegir;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 48),
        const Text(
          'Toma o elige una foto de cuerpo completo, vertical y de frente, '
          'con la ropa que usaste.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => onElegir(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Cámara'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => onElegir(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galería'),
        ),
      ],
    );
  }
}

/// Cuadro cian con fecha, ubicación y clima de la foto (mismo estilo que Historial).
class _DatosFoto extends StatelessWidget {
  const _DatosFoto({required this.clima});
  final ClimaFoto clima;

  static String _ubicacion(OrigenUbicacion o) => switch (o) {
    OrigenUbicacion.foto => 'Ubicación: GPS de la foto',
    OrigenUbicacion.guardada =>
      'Ubicación: última guardada (la foto no trae GPS)',
    OrigenUbicacion.porDefecto =>
      'Ubicación: Santiago (sin ubicación disponible)',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Texto oscuro fijo: el cian es claro en ambos temas
    final cuerpo = text.bodySmall?.copyWith(color: Colors.black87);
    final titulo = text.titleSmall?.copyWith(color: Colors.black87);
    final meta = clima.metadata;
    final c = clima.clima;

    return ListenableBuilder(
      listenable: AjustesController.instance,
      builder: (context, _) {
        final a = AjustesController.instance.ajustes;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.wColors.acento,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatearFechaHora(meta.fechaHora, formato: a.formatoFecha),
                style: titulo,
              ),
              if (!meta.fechaDesdeExif)
                Text(
                  'La foto no trae fecha de captura: se usó la del archivo.',
                  style: cuerpo,
                ),
              const SizedBox(height: 6),
              Text(
                '${formatearTemperatura(c.temperatura, a.unidadTemperatura)}'
                ' · ${c.condicion} · humedad ${c.humedad.round()}%',
                style: cuerpo,
              ),
              Text(_ubicacion(clima.origenUbicacion), style: cuerpo),
            ],
          ),
        );
      },
    );
  }
}

/// Línea bajo el título de cada selector: qué vio el modelo y si hay que confirmar.
class _EstadoSlot extends StatelessWidget {
  const _EstadoSlot({required this.slot, required this.opcional});
  final SlotPropuesta slot;
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall;
    final det = slot.deteccion;

    if (opcional && slot.propuesta == null) {
      return Text('No detectada · toca una para agregarla', style: estilo);
    }
    final texto = det == null
        ? 'No detectada en la foto: elige cuál usaste'
        : 'Detectado: ${det.label} (${(det.confidence * 100).round()}%)';

    if (!slot.requiereConfirmacion) return Text(texto, style: estilo);
    return Row(
      children: [
        Icon(
          Icons.help_outline,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 4),
        Expanded(child: Text('$texto · confírmala', style: estilo)),
      ],
    );
  }
}
