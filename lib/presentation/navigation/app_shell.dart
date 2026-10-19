import 'package:flutter/material.dart';
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

  // Index conserva el estado de cada pestaña al cambiar
  static const _screens = <Widget>[
    HomeScreen(),
    PrendasScreen(),
    Center(child: Text('Historial (pendiente)')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
