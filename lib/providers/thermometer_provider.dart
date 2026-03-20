// ─────────────────────────────────────────────────────────────
//  lib/providers/thermometer_provider.dart
//  Всё состояние приложения — один ChangeNotifier
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/temperature.dart';
import '../services/ble_service.dart';

const _kUnitPrefKey = 'temperature_unit';

/// Максимум точек в истории (180 сек = 3 мин при 1 замере/сек)
const _kMaxHistory = 180;

class ThermometerProvider extends ChangeNotifier {
  // ── Зависимости ───────────────────────────────────────────

  final BleService        _ble;
  final SharedPreferences _prefs;

  ThermometerProvider({
    required BleService        ble,
    required SharedPreferences prefs,
  })  : _ble   = ble,
        _prefs = prefs {
    _init();
  }

  // ── BLE-состояние ─────────────────────────────────────────

  BleStatus _status = BleStatus.idle;
  BleStatus get status => _status;

  TemperatureValue? _temperature;
  TemperatureValue? get temperature => _temperature;

  bool _sensorError = false;
  bool get sensorError => _sensorError;

  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Единица измерения ─────────────────────────────────────

  TemperatureUnit _unit = TemperatureUnit.celsius;
  TemperatureUnit get unit => _unit;

  // ── История измерений (ручная запись) ─────────────────────

  final List<TemperatureValue> _history = [];
  List<TemperatureValue> get history => List.unmodifiable(_history);

  /// Запись активна — новые значения добавляются в историю
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Есть ли данные для отображения / экспорта
  bool get hasHistory => _history.isNotEmpty;

  double? get sessionMinC => _history.isEmpty
      ? null
      : _history.map((v) => v.celsius).reduce((a, b) => a < b ? a : b);

  double? get sessionMaxC => _history.isEmpty
      ? null
      : _history.map((v) => v.celsius).reduce((a, b) => a > b ? a : b);

  double? get sessionAvgC => _history.isEmpty
      ? null
      : _history.map((v) => v.celsius).reduce((a, b) => a + b) /
            _history.length;

  // ── Подписки ──────────────────────────────────────────────

  StreamSubscription<BleStatus>?          _statusSub;
  StreamSubscription<TemperatureReading>? _readingSub;
  StreamSubscription<List<ScanResult>>?   _scanSub;
  StreamSubscription<bool>?               _scanningSub;

  // ── Инициализация ─────────────────────────────────────────

  void _init() {
    final saved = _prefs.getString(_kUnitPrefKey);
    if (saved != null) _unit = TemperatureUnit.fromStorageKey(saved);

    _statusSub = _ble.statusStream.listen((s) {
      _status = s;
      _errorMessage = s == BleStatus.error
          ? 'Ошибка BLE. Проверь, включён ли Bluetooth.'
          : null;
      if (s == BleStatus.disconnected || s == BleStatus.idle) {
        _temperature = null;
        _sensorError = false;
        // Запись останавливаем при разрыве, данные сохраняем
        _isRecording = false;
      }
      notifyListeners();
    });

    _readingSub = _ble.readingStream.listen((reading) {
      switch (reading) {
        case TemperatureValue():
          _temperature = reading;
          _sensorError = false;
          // Добавляем в историю только если запись активна
          if (_isRecording) {
            _history.add(reading);
            if (_history.length > _kMaxHistory) _history.removeAt(0);
          }
        case TemperatureSensorError():
          _sensorError = true;
      }
      notifyListeners();
    });

    _scanSub = _ble.scanResults.listen((results) {
      _scanResults = results;
      notifyListeners();
    });

    _scanningSub = _ble.isScanning.listen((scanning) {
      _isScanning = scanning;
      if (!scanning && _status == BleStatus.scanning) {
        _status = BleStatus.idle;
      }
      notifyListeners();
    });
  }

  // ── BLE-методы ────────────────────────────────────────────

  Future<void> startScan() async {
    _scanResults  = [];
    _errorMessage = null;
    notifyListeners();
    await _ble.startScan();
  }

  Future<void> stopScan() => _ble.stopScan();

  Future<void> connectTo(BluetoothDevice device) async {
    await _ble.stopScan();
    await _ble.connect(device);
  }

  Future<void> disconnect() => _ble.disconnect();

  void setUnit(TemperatureUnit unit) {
    _unit = unit;
    _prefs.setString(_kUnitPrefKey, unit.storageKey);
    notifyListeners();
  }

  // ── Управление записью ────────────────────────────────────

  /// Начать запись. Очищает предыдущую историю.
  void startRecording() {
    _history.clear();
    _isRecording = true;
    notifyListeners();
  }

  /// Остановить запись. История сохраняется для просмотра и экспорта.
  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }

  /// Остановить запись и очистить историю.
  void resetRecording() {
    _isRecording = false;
    _history.clear();
    notifyListeners();
  }

  // ── Освобождение ресурсов ─────────────────────────────────

  @override
  void dispose() {
    _statusSub?.cancel();
    _readingSub?.cancel();
    _scanSub?.cancel();
    _scanningSub?.cancel();
    _ble.dispose();
    super.dispose();
  }
}
