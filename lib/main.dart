import 'package:flutter/material.dart';
import 'package:weathwear/domain/scheduler/etl_scheduler.dart';
import 'package:weathwear/presentation/navigation/app_shell.dart';
import 'package:weathwear/core/theme/app_theme.dart';

Future<void> main() async {
  //Necesario cuando se usa codigo async antes de runApp().
  WidgetsFlutterBinding.ensureInitialized();

  final scheduler = EtlScheduler();
  await scheduler.initialize();
  await scheduler.shedulerPeriodic();

  runApp(const WeathwearApp());
}

class WeathwearApp extends StatelessWidget {
  const WeathwearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weathwear',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
