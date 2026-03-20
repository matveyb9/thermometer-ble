# Thermometer — BLE термометр на ESP32 + DS18B20

Мобильное приложение Flutter + прошивка ESP32 для беспроводного
мониторинга температуры по Bluetooth Low Energy.

---

## Компоненты

| Компонент | Описание |
|---|---|
| ESP32 DevKit-C | Микроконтроллер с BLE |
| DS18B20 (влагозащищённый) | Цифровой датчик температуры |
| Резистор 4.7 кОм | Подтягивающий, между DATA и 3.3V |
| Смартфон Android / iPhone | Для запуска приложения |

---

## Схема подключения DS18B20

```
ESP32 DevKit-C          DS18B20
────────────────        ────────────
3.3V  ────────────────── Красный (VCC)
GND   ────────────────── Чёрный (GND)
GPIO4 ────────────────── Жёлтый (DATA)
  │
  └── [4.7 кОм] ── 3.3V   ← подтягивающий резистор
```

> **Важно:** резистор 4.7 кОм между DATA и 3.3V обязателен —
> без него датчик не будет отвечать.

Протокол 1-Wire требует именно подтягивающего резистора к питанию,
а не к GND.

---

## Структура репозитория

```
thermometer/          ← Flutter-приложение
├── lib/
│   ├── main.dart                       # точка входа
│   ├── app.dart                        # MaterialApp + тема
│   ├── models/temperature.dart         # модель + конвертация единиц
│   ├── services/ble_service.dart       # BLE: сканирование, подключение
│   ├── providers/thermometer_provider.dart  # состояние приложения
│   └── screens/
│       ├── scan_screen.dart            # список BLE-устройств
│       └── home_screen.dart            # отображение температуры
├── android/
│   ├── settings.gradle.kts
│   └── app/
│       ├── build.gradle.kts
│       └── src/main/AndroidManifest.xml
├── ios/
│   ├── Podfile
│   └── Runner/Info.plist
├── pubspec.yaml
└── analysis_options.yaml

thermometer_ble/      ← Arduino-скетч ESP32
└── thermometer_ble.ino
```

---

## BLE-идентификаторы

Должны совпадать в прошивке и приложении:

| Параметр | Значение |
|---|---|
| Имя устройства | `ESP32-Thermo` |
| Service UUID | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Characteristic UUID | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Формат данных | UTF-8 строка `"23.50"` (°C) или `"ERR"` |

---

## Сборка и запуск

### Прошивка ESP32

1. Установи [Arduino IDE](https://www.arduino.cc/en/software)
2. Добавь менеджер плат `esp32 by Espressif Systems` (версия 3.x)
3. Установи библиотеки через Library Manager:
   - `OneWire` by Paul Stoffregen
   - `DallasTemperature` by Miles Burton
4. Выбери плату: **ESP32 Dev Module**
5. Открой `thermometer_ble/thermometer_ble.ino` и прошей

После прошивки открой **Serial Monitor** (115200 бод):
```
=== ESP32 BLE Thermometer ===
[DS18B20] Найдено устройств: 1
[BLE] Реклама запущена. Ищи устройство: ESP32-Thermo
```

### Flutter-приложение

```bash
# Зависимости
flutter pub get

# Android
flutter run

# iOS (требует macOS + Xcode)
cd ios && pod install && cd ..
flutter run
```

---

## Требования

| Платформа | Минимальная версия |
|---|---|
| Android | 5.0 (API 21) |
| iOS | 13.0 |
| Flutter SDK | 3.41.2 |
| Dart SDK | 3.11 |
| ESP32 Arduino Core | 3.x |

---

## Зависимости Flutter

| Пакет | Версия | Назначение |
|---|---|---|
| `flutter_blue_plus` | `^2.1.0` | BLE |
| `provider` | `^6.1.5` | Управление состоянием |
| `shared_preferences` | `^2.3.0` | Сохранение выбранной единицы |

---

## Пакетные имена

| Платформа | ID |
|---|---|
| Android `applicationId` | `ru.matveyb9.diy.thermometer` |
| iOS `bundleId` | `ru.matveyb9.diy.thermometer` |
| Dart package name | `thermometer` |
