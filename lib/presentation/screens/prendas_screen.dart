import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:weathwear/data/models/prenda_model.dart';
import 'package:weathwear/data/repositories/prenda_repository.dart';
import 'package:weathwear/presentation/screens/editar_prenda_screen.dart';
import 'package:weathwear/presentation/screens/registrar_prenda_screen.dart';

class PrendasScreen extends StatefulWidget {
  const PrendasScreen({super.key, this.loader});

  /// Inyectable para tests. Si es null usa el repositorio real.
  final Future<List<PrendaModel>> Function()? loader;

  @override
  State<PrendasScreen> createState() => _PrendasScreenState();
}

class _PrendasScreenState extends State<PrendasScreen> {
  late Future<List<PrendaModel>> _future;
  bool _menuAbierto = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PrendaModel>> _load() =>
      widget.loader != null ? widget.loader!() : PrendaRepository().getAll();

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  // Abre el registro directo en cámara o galería; si se guardó, recarga
  Future<void> _abrirRegistro(ImageSource source) async {
    setState(() => _menuAbierto = false);
    final registrada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistrarPrendaScreen(initialSource: source),
      ),
    );
    if (registrada == true && mounted) _reload();
  }

  // Abre la edición de una prenda; si hubo cambios, recarga la grilla
  Future<void> _editar(PrendaModel prenda) async {
    final cambiada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditarPrendaScreen(prenda: prenda)),
    );
    if (cambiada == true && mounted) _reload();
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomRight,
          child: _menuAbierto
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // heroTag distinto por botón: evita conflicto entre FABs
                    FloatingActionButton.extended(
                      heroTag: 'fab_camara',
                      onPressed: () => _abrirRegistro(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'fab_galeria',
                      onPressed: () => _abrirRegistro(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'fab_principal',
          onPressed: () => setState(() => _menuAbierto = !_menuAbierto),
          tooltip: _menuAbierto ? 'Cerrar' : 'Agregar prenda',
          child: Icon(_menuAbierto ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _buildFab(),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<PrendaModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final prendas = snap.data ?? const <PrendaModel>[];
            // ListView en el caso vacío para que el pull-to-refresh funcione
            if (snap.hasError || prendas.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Text(
                      snap.hasError
                          ? 'No se pudieron cargar las prendas.'
                          : 'Aún no tienes prendas registradas.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: prendas.length,
              itemBuilder: (_, i) => _PrendaCard(
                prenda: prendas[i],
                onTap: () => _editar(prendas[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrendaCard extends StatelessWidget {
  const _PrendaCard({required this.prenda, required this.onTap});
  final PrendaModel prenda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      // InkWell dentro del Card: el ripple se dibuja sobre la imagen
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.file(
                File(prenda.imagenRuta),
                fit: BoxFit.cover,
                // Si el archivo se borró, la tarjeta no rompe la grilla
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.checkroom_outlined, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prenda.tipo, style: text.titleSmall),
                  Text(
                    '${prenda.tempMin.round()}–${prenda.tempMax.round()}°C · '
                    '${prenda.condiciones.join(', ')}',
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
