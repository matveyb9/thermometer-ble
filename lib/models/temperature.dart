// ─────────────────────────────────────────────────────────────
//  lib/models/temperature.dart
//  Модель температуры + конвертация между единицами
// ─────────────────────────────────────────────────────────────

/// Единица измерения температуры
enum TemperatureUnit {
  celsius,
  fahrenheit,
  kelvin;

  /// Отображаемое название кнопки
  String get label {
    switch (this) {
      case TemperatureUnit.celsius:    return '°C';
      case TemperatureUnit.fahrenheit: return '°F';
      case TemperatureUnit.kelvin:     return 'K';
    }
  }

  /// Ключ для сохранения в SharedPreferences
  String get storageKey => name; // 'celsius' | 'fahrenheit' | 'kelvin'

  static TemperatureUnit fromStorageKey(String key) {
    return TemperatureUnit.values.firstWhere(
      (u) => u.storageKey == key,
      orElse: () => TemperatureUnit.celsius,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Sealed class — результат одного BLE-измерения.
//  Либо успешное значение, либо ошибка датчика.
//
//  Использование (exhaustive switch, Dart 3):
//    switch (reading) {
//      case TemperatureValue(:final celsius): ...
//      case TemperatureSensorError():        ...
//    }
// ─────────────────────────────────────────────────────────────

sealed class TemperatureReading {}

/// Успешное измерение
final class TemperatureValue extends TemperatureReading {
  TemperatureValue({required this.celsius, required this.receivedAt});

  /// Значение всегда хранится в Цельсиях как источник истины
  final double   celsius;
  final DateTime receivedAt;

  double get fahrenheit => celsius * 9 / 5 + 32;
  double get kelvin     => celsius + 273.15;

  /// Возвращает значение в нужной единице
  double inUnit(TemperatureUnit unit) => switch (unit) {
    TemperatureUnit.celsius    => celsius,
    TemperatureUnit.fahrenheit => fahrenheit,
    TemperatureUnit.kelvin     => kelvin,
  };

  /// Форматированная строка для отображения: "23.5"
  String formatted(TemperatureUnit unit) => inUnit(unit).toStringAsFixed(1);
}

/// Ошибка датчика (ESP32 прислал "ERR")
final class TemperatureSensorError extends TemperatureReading {
  const TemperatureSensorError();
}
