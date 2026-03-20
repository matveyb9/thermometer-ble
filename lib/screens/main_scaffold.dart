// ─────────────────────────────────────────────────────────────
//  lib/screens/main_scaffold.dart
//  Главный каркас: две вкладки + кнопка подключения + DeviceSheet
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/thermometer_provider.dart';
import '../services/ble_service.dart';
import '../services/permission_service.dart';
import '../widgets/device_sheet.dart';
import 'chart_tab.dart';
import 'temperature_tab.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  int       _tabIndex      = 0;
  bool      _sheetVisible  = false;
  BleStatus _prevStatus    = BleStatus.idle;

  late final AnimationController _sheetAnim;
  late final Animation<Offset>   _sheetSlide;

  @override
  void initState() {
    super.initState();
    _sheetAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 260),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sheetAnim,
      curve:  Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _sheetAnim.dispose();
    super.dispose();
  }

  // ── Показать / скрыть панель устройств ───────────────────

  Future<void> _openSheet() async {
    // Запрашиваем разрешения перед сканированием
    final status = await PermissionService.instance.requestBlePermissions();
    if (!mounted) return;

    if (status == BlePermissionStatus.permanentlyDenied) {
      await _showPermissionDialog();
      return;
    }
    if (status == BlePermissionStatus.denied) return;

    setState(() => _sheetVisible = true);
    _sheetAnim.forward();
    context.read<ThermometerProvider>().startScan();
  }

  void _closeSheet() {
    _sheetAnim.reverse().then((_) {
      if (mounted) setState(() => _sheetVisible = false);
    });
    context.read<ThermometerProvider>().stopScan();
  }

  Future<void> _showPermissionDialog() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Разрешения заблокированы'),
        content: const Text(
          'Разрешения Bluetooth отклонены навсегда.\n'
          'Открой настройки приложения и выдай их вручную.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child:     const Text('Настройки'),
          ),
        ],
      ),
    );
    if (go == true) await PermissionService.instance.openSettings();
  }

  // ── Кнопка подключения / отключения ──────────────────────

  Future<void> _onConnectPressed(ThermometerProvider provider) async {
    if (provider.status == BleStatus.connected) {
      // Подтверждение отключения
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title:   const Text('Отключиться?'),
          content: const Text('Соединение с ESP32 будет разорвано.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:     const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:     const Text('Отключить'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (ok == true) await provider.disconnect();
    } else if (_sheetVisible) {
      _closeSheet();
    } else {
      await _openSheet();
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThermometerProvider>();

    // Закрываем панель когда подключение установлено.
    // Сравниваем с предыдущим статусом чтобы не вызывать
    // _closeSheet() при каждой перестройке.
    final currentStatus = provider.status;
    if (currentStatus != _prevStatus) {
      _prevStatus = currentStatus;
      if (currentStatus == BleStatus.connected && _sheetVisible) {
        // Используем microtask чтобы не вызывать setState во время build
        Future.microtask(_closeSheet);
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      // ── AppBar ────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('Thermometer'),
        actions: [
          _ConnectButton(
            status:    provider.status,
            isScanning: provider.isScanning,
            sheetOpen: _sheetVisible,
            onPressed: () => _onConnectPressed(provider),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body: вкладки + выпадающая панель ────────────────
      body: Stack(
        children: [
          // Основные экраны (IndexedStack сохраняет состояние вкладок)
          IndexedStack(
            index: _tabIndex,
            children: const [
              TemperatureTab(),
              ChartTab(),
            ],
          ),

          // Затемнение под панелью
          if (_sheetVisible)
            GestureDetector(
              onTap: _closeSheet,
              child: AnimatedOpacity(
                opacity: _sheetVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(color: Colors.black26),
              ),
            ),

          // Выпадающая панель устройств
          if (_sheetVisible)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _sheetSlide,
                child: DeviceSheet(onClose: _closeSheet),
              ),
            ),
        ],
      ),

      // ── BottomNavigationBar ───────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
          if (_sheetVisible) _closeSheet();
        },
        destinations: [
          NavigationDestination(
            icon:         const Icon(Icons.thermostat_outlined),
            selectedIcon: const Icon(Icons.thermostat),
            label:        'Температура',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.show_chart_outlined),
            selectedIcon: Badge(
              isLabelVisible: provider.isRecording,
              smallSize: 8,
              backgroundColor: theme.colorScheme.error,
              child: const Icon(Icons.show_chart),
            ),
            label: 'График',
          ),
        ],
      ),
    );
  }
}

// ── Кнопка подключения в AppBar ──────────────────────────────

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({
    required this.status,
    required this.isScanning,
    required this.sheetOpen,
    required this.onPressed,
  });

  final BleStatus    status;
  final bool         isScanning;
  final bool         sheetOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Во время сканирования и подключения — spinner вместо кнопки
    if (isScanning || status == BleStatus.connecting) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    final connected = status == BleStatus.connected;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: connected
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          connected ? 'Отключиться' : 'Подключить',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
