// ─────────────────────────────────────────────────────────────
//  lib/widgets/device_sheet.dart
//  Выпадающая панель со списком BLE-устройств.
//  Появляется сверху при нажатии кнопки подключения.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/thermometer_provider.dart';
import '../services/ble_service.dart';

class DeviceSheet extends StatelessWidget {
  const DeviceSheet({super.key, required this.onClose});

  /// Вызывается когда пользователь закрывает панель вручную.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThermometerProvider>();
    final theme    = Theme.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Заголовок ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Индикатор сканирования / состояния
                  _StatusIndicator(provider: provider),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _headerTitle(provider),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Кнопка закрытия
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClose,
                    tooltip: 'Закрыть',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Содержимое ───────────────────────────────
            _buildContent(context, provider, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThermometerProvider provider,
    ThemeData theme,
  ) {
    // Идёт подключение
    if (provider.status == BleStatus.connecting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Подключение...'),
          ],
        ),
      );
    }

    // Ошибка BLE
    if (provider.status == BleStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.bluetooth_disabled,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                provider.errorMessage ?? 'Bluetooth недоступен',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Нет результатов
    if (provider.scanResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.bluetooth_searching,
                size: 36, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 8),
            Text(
              provider.isScanning
                  ? 'Ищем ESP32-Thermo...'
                  : 'Устройства не найдены',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Список устройств
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: provider.scanResults.length,
      itemBuilder: (context, i) {
        final result = provider.scanResults[i];
        final device = result.device;
        final name   = device.platformName.isNotEmpty
            ? device.platformName
            : 'Неизвестное устройство';

        return ListTile(
          dense: true,
          leading: const Icon(Icons.bluetooth, size: 20),
          title: Text(name, style: const TextStyle(fontSize: 14)),
          subtitle: Text(
            device.remoteId.toString(),
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            '${result.rssi} dBm',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          onTap: () => provider.connectTo(device),
        );
      },
    );
  }

  String _headerTitle(ThermometerProvider p) {
    if (p.status == BleStatus.connecting) return 'Подключение';
    if (p.status == BleStatus.error) return 'Ошибка';
    if (p.isScanning) return 'Поиск устройств';
    if (p.scanResults.isEmpty) return 'Поиск устройств';
    return 'Выбери устройство';
  }
}

// ── Маленький анимированный индикатор статуса ────────────────

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.provider});

  final ThermometerProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isScanning || provider.status == BleStatus.connecting) {
      return const SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    if (provider.status == BleStatus.error) {
      return Icon(Icons.error_outline,
          size: 16,
          color: Theme.of(context).colorScheme.error);
    }
    return Icon(Icons.bluetooth_searching,
        size: 16,
        color: Theme.of(context).colorScheme.primary);
  }
}
