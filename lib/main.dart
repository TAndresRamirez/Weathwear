import 'package:flutter/material.dart';

Future<void> main() async {
  //Necesario cuando se usa codigo async antes de runApp().
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const WeathwearApp());
}

class WeathwearApp extends StatelessWidget {
  const WeathwearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weathwear',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const Scaffold(body: Center(child: Text('Weathwear'))),
    );
  }
}
