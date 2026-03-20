// ─────────────────────────────────────────────────────────────
//  lib/main.dart
//  Точка входа — инициализация зависимостей и запуск приложения
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/thermometer_provider.dart';
import 'services/ble_service.dart';

Future<void> main() async {
  // Обязательно для async в main() до runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем SharedPreferences до запуска UI
  final prefs = await SharedPreferences.getInstance();

  runApp(
    // ChangeNotifierProvider создаёт ThermometerProvider
    // и автоматически вызовет dispose() при уничтожении виджета
    ChangeNotifierProvider(
      create: (_) => ThermometerProvider(
        ble:   BleService(),
        prefs: prefs,
      ),
      child: const ThermometerApp(),
    ),
  );
}
