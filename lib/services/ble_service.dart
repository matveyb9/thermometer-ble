// ─────────────────────────────────────────────────────────────
//  lib/services/ble_service.dart
//  Работа с BLE: сканирование, подключение, чтение характеристики
//
//  UUID-константы должны совпадать с прошивкой ESP32.
//  Задаются здесь как единственный источник истины.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/temperature.dart';

/// UUID сервиса и характеристики — должны совпадать с ESP32-скетчем
class BleUuids {
  BleUuids._();

  static const String service        = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String characteristic = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
}

/// Имя устройства для автоматической фильтрации при сканировании
const String kDeviceName = 'ESP32-Thermo';

/// Таймаут подключения к устройству
const Duration _kConnectTimeout = Duration(seconds: 15);

/// Состояние BLE-соединения
enum BleStatus {
  idle,          // не подключены, не сканируем
  scanning,      // идёт сканирование
  connecting,    // устанавливается соединение
  connected,     // подключены, данные поступают
  disconnected,  // соединение потеряно
  error,         // ошибка (BLE выключен и т.п.)
}

class BleService {
  // ── Публичные стримы ──────────────────────────────────────

  /// Найденные при сканировании устройства
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// Идёт ли сканирование прямо сейчас
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  // ── Приватное состояние ───────────────────────────────────

  BluetoothDevice?                              _device;
  BluetoothCharacteristic?                      _characteristic;
  StreamSubscription<List<int>>?                _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connSubscription;

  final _statusController  = StreamController<BleStatus>.broadcast();
  final _readingController = StreamController<TemperatureReading>.broadcast();

  Stream<BleStatus>          get statusStream  => _statusController.stream;

  /// Стрим результатов измерений.
  /// Может нести TemperatureValue или TemperatureSensorError.
  Stream<TemperatureReading> get readingStream => _readingController.stream;

  // ── Сканирование ──────────────────────────────────────────

  /// Запустить сканирование (до 10 секунд, только наше устройство)
  Future<void> startScan() async {
    if (await FlutterBluePlus.isSupported == false) {
      _statusController.add(BleStatus.error);
      return;
    }

    _statusController.add(BleStatus.scanning);

    await FlutterBluePlus.startScan(
      withNames: [kDeviceName],
      timeout:   const Duration(seconds: 10),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    // Сбрасываем в idle только если не было активного подключения —
    // stopScan() вызывается и перед connect(), статус тогда не трогаем
    if (_statusController.isClosed) return;
    final current = _device == null ? BleStatus.idle : null;
    if (current != null) _statusController.add(current);
  }

  // ── Подключение ───────────────────────────────────────────

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    _statusController.add(BleStatus.connecting);

    try {
      await device.connect(
        autoConnect: false,
        timeout:     _kConnectTimeout,
      );
    } catch (e) {
      debugPrint('[BleService] connect() error: $e');
      _device = null;
      _statusController.add(BleStatus.error);
      return;
    }

    // Слушаем разрывы соединения
    _connSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _notifySubscription?.cancel();
        _statusController.add(BleStatus.disconnected);
      }
    });

    await _discoverAndSubscribe(device);
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await _connSubscription?.cancel();
    await _device?.disconnect();
    _device         = null;
    _characteristic = null;
    _statusController.add(BleStatus.idle);
  }

  // ── Обнаружение сервиса и подписка на notify ─────────────

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() ==
            BleUuids.service.toLowerCase()) {
          for (final c in service.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                BleUuids.characteristic.toLowerCase()) {
              _characteristic = c;
              break;
            }
          }
          break;
        }
      }

      if (_characteristic == null) {
        debugPrint('[BleService] Характеристика не найдена. '
            'Проверь UUID в прошивке ESP32.');
        _statusController.add(BleStatus.error);
        return;
      }

      // Включаем уведомления — ESP32 будет сам присылать температуру
      await _characteristic!.setNotifyValue(true);
      _statusController.add(BleStatus.connected);

      _notifySubscription = _characteristic!.lastValueStream.listen((bytes) {
        if (bytes.isEmpty) return;

        final raw = String.fromCharCodes(bytes).trim();

        if (raw == 'ERR') {
          // ESP32 сообщает об ошибке датчика DS18B20
          _readingController.add(const TemperatureSensorError());
          return;
        }

        final celsius = double.tryParse(raw);
        if (celsius != null) {
          _readingController.add(
            TemperatureValue(
              celsius:    celsius,
              receivedAt: DateTime.now(),
            ),
          );
        }
        // Если пришло что-то непонятное — молча игнорируем,
        // UI продолжает показывать последнее известное значение
      });
    } catch (e) {
      debugPrint('[BleService] _discoverAndSubscribe() error: $e');
      _statusController.add(BleStatus.error);
    }
  }

  // ── Освобождение ресурсов ─────────────────────────────────

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _readingController.close();
  }
}
