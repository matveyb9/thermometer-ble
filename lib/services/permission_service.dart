// ─────────────────────────────────────────────────────────────
//  lib/services/permission_service.dart
//  Запрос разрешений для BLE
//
//  Android 12+ (API 31+): BLUETOOTH_SCAN + BLUETOOTH_CONNECT
//  Android 6–11          : ACCESS_FINE_LOCATION (нужна для BLE-scan)
//  iOS                   : диалог показывается системой автоматически
//                          на основе NSBluetoothAlwaysUsageDescription
//                          в Info.plist — permission_handler не нужен
// ─────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Итоговый статус запроса разрешений
enum BlePermissionStatus {
  granted,           // все нужные разрешения выданы, можно сканировать
  denied,            // отклонено — можно спросить снова
  permanentlyDenied, // «Больше не спрашивать» — вести в системные настройки
}

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Запрашивает все BLE-разрешения, необходимые для текущей платформы.
  /// Вызывай перед каждым [FlutterBluePlus.startScan].
  Future<BlePermissionStatus> requestBlePermissions() async {
    // iOS — диалог Bluetooth показывается CoreBluetooth автоматически,
    // никаких дополнительных запросов через permission_handler не нужно.
    if (!Platform.isAndroid) return BlePermissionStatus.granted;

    // Запрашиваем полный набор разрешений.
    // permission_handler 12 корректно обрабатывает версию Android:
    //   bluetoothScan / bluetoothConnect — реальные runtime-разрешения
    //   только на Android 12+ (API 31+); на более старых версиях
    //   библиотека вернёт PermissionStatus.granted автоматически.
    //   locationWhenInUse — нужна на Android 6–11 для BLE-сканирования;
    //   на Android 12+ игнорируется (нет нужды запрашивать).
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    debugPrint('[PermissionService] $statuses');

    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return BlePermissionStatus.permanentlyDenied;
    }
    if (statuses.values.any((s) => s.isDenied)) {
      return BlePermissionStatus.denied;
    }
    return BlePermissionStatus.granted;
  }

  /// Открыть системные настройки приложения.
  /// Вызывай при [BlePermissionStatus.permanentlyDenied].
  Future<void> openSettings() => openAppSettings();
}
