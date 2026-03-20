// ─────────────────────────────────────────────────────────────
//  lib/app.dart
//  MaterialApp + тема
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'screens/main_scaffold.dart';

class ThermometerApp extends StatelessWidget {
  const ThermometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'Thermometer',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:  Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:  Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: ThemeMode.system,
      home: const MainScaffold(),
    );
  }
}
