// ─────────────────────────────────────────────────────────────
//  lib/screens/temperature_tab.dart
//  Вкладка 1: большая температура + переключатель единиц
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/temperature.dart';
import '../providers/thermometer_provider.dart';
import '../services/ble_service.dart';

class TemperatureTab extends StatelessWidget {
  const TemperatureTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThermometerProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Основной дисплей ─────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _buildDisplay(context, provider),
            ),

            const Spacer(flex: 1),

            // ── Переключатель единиц ─────────────────────
            _UnitSelector(
              selected:  provider.unit,
              onChanged: provider.setUnit,
              enabled:   provider.status == BleStatus.connected,
            ),

            const Spacer(flex: 2),

            // ── Подсказка когда не подключено ────────────
            if (provider.status != BleStatus.connected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Нажми «Подключить» в заголовке',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay(BuildContext context, ThermometerProvider provider) {
    final theme = Theme.of(context);

    // Нет подключения
    if (provider.status != BleStatus.connected) {
      return Column(
        key: const ValueKey('disconnected'),
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 72,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет подключения',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    // Ошибка датчика
    if (provider.sensorError) {
      return Column(
        key: const ValueKey('sensor_error'),
        children: [
          Icon(Icons.thermostat_auto,
              size: 72, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Датчик не отвечает',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Проверь подключение DS18B20',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (provider.temperature != null) ...[
            const SizedBox(height: 14),
            Text(
              'Последнее: '
              '${provider.temperature!.formatted(provider.unit)} '
              '${provider.unit.label}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      );
    }

    // Ожидание первых данных
    if (provider.temperature == null) {
      return Column(
        key: const ValueKey('waiting'),
        children: [
          const SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Ожидание данных...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // Нормальное отображение
    final temp = provider.temperature!;
    final value = temp.formatted(provider.unit);
    final unit  = provider.unit.label;

    return Column(
      key: ValueKey('temp_${provider.unit}'),
      children: [
        // Большое число
        Row(
          mainAxisAlignment:  MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize:     108,
                fontWeight:   FontWeight.w200,
                color:        theme.colorScheme.primary,
                letterSpacing: -4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                unit,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),

        // Время обновления
        const SizedBox(height: 8),
        _LastUpdated(time: temp.receivedAt),
      ],
    );
  }
}

// ── Переключатель единиц ─────────────────────────────────────

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  final TemperatureUnit               selected;
  final ValueChanged<TemperatureUnit> onChanged;
  final bool                          enabled;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TemperatureUnit>(
      segments: TemperatureUnit.values
          .map((u) => ButtonSegment<TemperatureUnit>(
                value: u,
                label: Text(u.label),
              ))
          .toList(),
      selected:           {selected},
      onSelectionChanged: enabled ? (set) => onChanged(set.first) : null,
      style: SegmentedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}

// ── Время последнего обновления ──────────────────────────────

class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final t   = time;
    final hms = '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}:'
                '${t.second.toString().padLeft(2, '0')}';
    return Text(
      'Обновлено в $hms',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey,
        fontFamily: 'monospace',
      ),
    );
  }
}
