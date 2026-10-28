import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/domain/scheduler/etl_scheduler.dart';
import 'package:weathwear/domain/settings/ajustes_controller.dart';
import 'package:weathwear/presentation/navigation/app_shell.dart';

Future<void> main() async {
  // Necesario cuando se usa codigo async antes de runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Antes de runApp: así el primer frame ya usa el tema guardado (sin parpadeo)
  await AjustesController.instance.cargar();

  final scheduler = EtlScheduler();
  await scheduler.initialize();
  await scheduler.shedulerPeriodic();

  runApp(const WeathwearApp());
}

class WeathwearApp extends StatelessWidget {
  const WeathwearApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AjustesController.instance;
    // Solo el MaterialApp se reconstruye al cambiar un ajuste
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'Weathwear',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: controller.ajustes.tema,
        home: const AppShell(),
      ),
    );
  }
}
