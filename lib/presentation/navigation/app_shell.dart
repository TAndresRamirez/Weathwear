import 'package:flutter/material.dart';
import 'package:weathwear/presentation/screens/historial_screen.dart';
import 'package:weathwear/presentation/screens/home_screen.dart';
import 'package:weathwear/presentation/screens/prendas_screen.dart';

// Contenedor con barra inferior
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Cambiar la key recrea el Historial y fuerza una nueva lectura de la BD
  int _historialVersion = 0;

  void _onSelect(int i) => setState(() {
    // Solo al entrar desde otra pestaña, no al re-tocar la actual
    if (i == 2 && _index != 2) _historialVersion++;
    _index = i;
  });

  @override
  Widget build(BuildContext context) {
    // Ya no puede ser static const: la key del Historial cambia
    final screens = <Widget>[
      const HomeScreen(),
      const PrendasScreen(),
      HistorialScreen(key: ValueKey(_historialVersion)),
    ];

    return Scaffold(
      // IndexedStack conserva el estado de Hoy y Prendas al cambiar
      body: SafeArea(
        child: IndexedStack(index: _index, children: screens),
      ),
      bottomNavigationBar: NavigationBar(
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
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}
