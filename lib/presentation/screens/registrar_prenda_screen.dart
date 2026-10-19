import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/data/storage/prenda_image_storage.dart';
import 'package:weathwear/domain/etl/weathwear_code_mapper.dart';
import 'package:weathwear/domain/prendas/registrar_prenda_use_case.dart';
import 'package:weathwear/domain/recommendation/prenda_categoria.dart';
import 'package:weathwear/domain/vision/clothing_classifier.dart';
import 'package:weathwear/presentation/widgets/prenda_clima_fields.dart';

/// CU-02 + CU-05: foto -> sugerencia del modelo -> confirmar/corregir -> guardar.
/// Hace pop(true) si se registró una prenda.
class RegistrarPrendaScreen extends StatefulWidget {
  const RegistrarPrendaScreen({
    super.key,
    this.initialSource,
    this.useCase,
    this.pickImage,
  });

  /// Si viene del menú de la FAB, abre directamente la cámara o la galería.
  final ImageSource? initialSource;

  /// Inyectables para tests. Si son null se usan los reales.
  final RegistrarPrendaUseCase? useCase;
  final Future<String?> Function(ImageSource source)? pickImage;

  @override
  State<RegistrarPrendaScreen> createState() => _RegistrarPrendaScreenState();
}

class _RegistrarPrendaScreenState extends State<RegistrarPrendaScreen> {
  // Rangos iniciales por tipo; el usuario los ajusta con el slider
  static const _rangosIniciales = <String, RangeValues>{
    'Polera': RangeValues(18, 32),
    'Poleron': RangeValues(8, 18),
    'Chaqueta': RangeValues(0, 15),
    'Pantalon': RangeValues(5, 30),
    'Shorts': RangeValues(20, 35),
  };

  late final RegistrarPrendaUseCase _useCase;
  ClothingClassifier?
  _classifier; // solo si lo creamos nosotros (hay que cerrarlo)

  late ImageSource _source; // última fuente usada, para "Cambiar foto"
  bool _picking = false; // el selector de foto está abierto
  String? _path;
  bool _analizando = false;
  bool _guardando = false;
  PrendaAnalisis? _analisis;
  String? _aviso;

  String? _tipo;
  RangeValues _temps = const RangeValues(15, 25);
  final Set<String> _condiciones = {WeathwearCodeMapper.condiciones.first};

  @override
  void initState() {
    super.initState();
    if (widget.useCase != null) {
      _useCase = widget.useCase!;
    } else {
      _classifier = ClothingClassifier();
      _useCase = RegistrarPrendaUseCase(
        _classifier!,
        PrendaImageStorage(),
        PrendaRepository(),
      );
    }

    _source = widget.initialSource ?? ImageSource.gallery;
    // Viene del menú de la FAB: abre el selector sin mostrar botones intermedios
    if (widget.initialSource != null) {
      _picking = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _elegir(widget.initialSource!),
      );
    }
  }

  @override
  void dispose() {
    _classifier?.dispose(); // libera el Interpreter de TFLite
    super.dispose();
  }

  Future<String?> _pick(ImageSource source) async {
    if (widget.pickImage != null) return widget.pickImage!(source);
    final photo = await ImagePicker().pickImage(
      source: source,
      // Reduce el costo de decodificar y clasificar en el hilo principal
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return photo?.path;
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  // Fija el tipo y precarga su rango de temperatura habitual
  void _aplicarTipo(String tipo) {
    _tipo = tipo;
    _temps = _rangosIniciales[tipo] ?? _temps;
  }

  Future<void> _elegir(ImageSource source) async {
    if (!mounted) return;
    _source = source;
    setState(() => _picking = true);

    final String? path;
    try {
      path = await _pick(source);
    } catch (_) {
      if (!mounted) return;
      setState(() => _picking = false); // muestra los botones como respaldo
      _snack('No se pudo abrir la cámara o la galería');
      return;
    }
    if (!mounted) return;

    if (path == null) {
      // Cancelado: si venimos de la FAB y aún no hay foto, volvemos atrás
      if (_path == null && widget.initialSource != null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _picking = false);
      }
      return;
    }

    setState(() {
      _path = path;
      _picking = false;
      _analizando = true;
      _analisis = null;
      _aviso = null;
      _tipo = null;
    });

    try {
      final analisis = await _useCase.analizar(path);
      if (!mounted) return;
      setState(() {
        _analisis = analisis;
        final label = analisis.clasificacion.label;
        // Solo preselecciona si el label es un tipo que la app conoce
        if (PrendaCategoriaMapper.tiposValidos.contains(label)) {
          _aplicarTipo(label);
        }
      });
    } on ClassifierException {
      // Degradación: sin sugerencia, el usuario elige el tipo a mano
      if (mounted) {
        setState(
          () => _aviso = 'No se pudo clasificar automáticamente. Elige el tipo manualmente.',
        );
      }
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _useCase.registrar(
        sourcePath: _path!,
        tipo: _tipo!,
        tempMin: _temps.start,
        tempMax: _temps.end,
        // Orden canónico (el de la lista), separado por comas
        condicionAplicable: WeathwearCodeMapper.condiciones
            .where(_condiciones.contains)
            .join(','),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PrendaRegistroException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('No se pudo guardar la prenda');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva prenda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _path == null ? _buildElegirFoto() : _buildFormulario(),
      ),
    );
  }

  List<Widget> _buildElegirFoto() {
    // Mientras se abre el selector del sistema no mostramos botones
    if (_picking) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ];
    }
    return [
      const SizedBox(height: 48),
      const Text(
        'Toma o elige una foto de la prenda sobre un fondo simple.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => _elegir(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Cámara'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _elegir(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Galería'),
      ),
    ];
  }

  List<Widget> _buildFormulario() {
    final text = Theme.of(context).textTheme;
    final analisis = _analisis;
    return [
      SizedBox(
        height: 240,
        child: Image.file(
          File(_path!),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
        ),
      ),
      TextButton.icon(
        onPressed: _analizando || _guardando || _picking
            ? null
            : () => _elegir(_source),
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
            Text('Analizando prenda...'),
          ],
        )
      else ...[
        if (_aviso != null) Text(_aviso!, style: text.bodyMedium),
        if (analisis != null)
          Text(
            analisis.requiereConfirmacion
                ? 'Confianza baja (${(analisis.clasificacion.confidence * 100).round()}%). Confirma el tipo.'
                : 'Sugerido por el modelo (${(analisis.clasificacion.confidence * 100).round()}%). Puedes corregirlo.',
            style: text.bodyMedium,
          ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Tipo',
            border: OutlineInputBorder(),
          ),
          child: DropdownButton<String>(
            value: _tipo,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('Elige el tipo'),
            items: [
              for (final t in PrendaCategoriaMapper.tiposValidos)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (t) {
              if (t != null) setState(() => _aplicarTipo(t));
            },
          ),
        ),
        const SizedBox(height: 16),
        RangoTemperaturaField(
          values: _temps,
          onChanged: (v) => setState(() => _temps = v),
        ),
        const SizedBox(height: 8),
        CondicionesField(
          seleccionadas: _condiciones,
          onChanged: (c, seleccionada) => setState(() {
            if (seleccionada) {
              _condiciones.add(c);
            } else {
              _condiciones.remove(c);
            }
          }),
        ),
        const SizedBox(height: 24),
        FilledButton(
          // Sin tipo o sin condiciones no se puede guardar
          onPressed: _tipo == null || _condiciones.isEmpty || _guardando
              ? null
              : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar prenda'),
        ),
      ],
    ];
  }
}
