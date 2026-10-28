import 'package:flutter/material.dart';
import 'package:weathwear/presentation/screens/historial_screen.dart';
import 'package:weathwear/presentation/screens/home_screen.dart';
import 'package:weathwear/presentation/screens/prendas_screen.dart';
import 'package:weathwear/presentation/widgets/app_background.dart';
import 'package:weathwear/presentation/widgets/configuracion_dialog.dart';

// Contenedor: fondo + barra superior con engranaje + pestañas + barra inferior flotante
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Cambiar la key recrea la pantalla y fuerza una nueva lectura de la BD
  int _prendasVersion = 0;
  int _historialVersion = 0;

  void _onSelect(int i) => setState(() {
    // Solo al entrar desde otra pestaña, no al re-tocar la actual
    if (i != _index) {
      if (i == 1) _prendasVersion++;
      if (i == 2) _historialVersion++;
    }
    _index = i;
  });

  void _abrirConfiguracion() {
    showDialog<void>(
      context: context,
      builder: (_) => const ConfiguracionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const HomeScreen(),
      PrendasScreen(key: ValueKey(_prendasVersion)), // ya no es const
      HistorialScreen(key: ValueKey(_historialVersion)),
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Barra superior fija: el engranaje es común a las 3 pestañas
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 32),
                    tooltip: 'Configuración',
                    onPressed: _abrirConfiguracion,
                  ),
                ),
              ),
              // IndexedStack conserva el estado de cada pestaña al cambiar
              Expanded(
                child: IndexedStack(index: _index, children: screens),
              ),
              // Barra flotante con esquinas redondeadas (NavigationBar no tiene margen propio)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _onSelect,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.wb_sunny_outlined),
                        label: 'Hoy',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.checkroom_outlined),
                        label: 'Prendas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.history),
                        label: 'Historial',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
