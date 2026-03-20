// ─────────────────────────────────────────────────────────────
//  lib/screens/chart_tab.dart
//  Вкладка 2: компактный дисплей + график + управление записью
// ─────────────────────────────────────────────────────────────

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/temperature.dart';
import '../providers/thermometer_provider.dart';
import '../services/ble_service.dart';
import '../services/export_service.dart';

class ChartTab extends StatefulWidget {
  const ChartTab({super.key});

  @override
  State<ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<ChartTab> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThermometerProvider>();
    final theme    = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // ── Компактная строка: температура + статистика ──
            _buildTopBar(provider, theme),
            const SizedBox(height: 12),

            // ── График ───────────────────────────────────────
            Expanded(child: _buildChart(provider, theme)),

            const SizedBox(height: 12),

            // ── Кнопки управления ────────────────────────────
            _buildControls(provider, theme),
          ],
        ),
      ),
    );
  }

  // ── Верхняя строка ───────────────────────────────────────

  Widget _buildTopBar(ThermometerProvider provider, ThemeData theme) {
    final temp  = provider.temperature;
    final unit  = provider.unit;
    final value = temp?.formatted(unit) ?? '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Текущая температура — небольшими цифрами
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight:  FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TextSpan(
                text: ' ${unit.label}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Статистика (только если есть история)
        if (provider.hasHistory)
          Expanded(
            child: _StatsRow(
              minC:  provider.sessionMinC,
              maxC:  provider.sessionMaxC,
              avgC:  provider.sessionAvgC,
              unit:  unit,
              theme: theme,
            ),
          )
        else
          Expanded(
            child: Text(
              provider.isRecording
                  ? 'Запись...'
                  : 'Нажми Старт для записи',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        // Индикатор записи
        if (provider.isRecording)
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  // ── График ───────────────────────────────────────────────

  Widget _buildChart(ThermometerProvider provider, ThemeData theme) {
    if (!provider.hasHistory) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart,
                  size: 48,
                  color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              Text(
                provider.status == BleStatus.connected
                    ? 'Нажми Старт чтобы начать запись'
                    : 'Подключись к устройству',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _LineChartCard(
      history: provider.history,
      unit:    provider.unit,
      theme:   theme,
    );
  }

  // ── Кнопки управления ────────────────────────────────────

  Widget _buildControls(ThermometerProvider provider, ThemeData theme) {
    final connected = provider.status == BleStatus.connected;

    return Row(
      children: [
        Expanded(
          child: _ControlButton(
            label:   'Старт',
            icon:    Icons.play_arrow_rounded,
            color:   theme.colorScheme.primary,
            enabled: connected && !provider.isRecording,
            onTap:   provider.startRecording,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ControlButton(
            label:   'Стоп',
            icon:    Icons.stop_rounded,
            color:   theme.colorScheme.error,
            enabled: provider.isRecording,
            onTap:   provider.stopRecording,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ControlButton(
            label:   'Сброс',
            icon:    Icons.refresh_rounded,
            color:   theme.colorScheme.secondary,
            enabled: provider.hasHistory || provider.isRecording,
            onTap:   provider.resetRecording,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ControlButton(
            label:   _exporting ? '...' : 'CSV',
            icon:    Icons.share_rounded,
            color:   Colors.teal,
            enabled: provider.hasHistory && !_exporting,
            onTap:   () => _exportCsv(provider.history),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCsv(List<TemperatureValue> history) async {
    setState(() => _exporting = true);
    final ok = await ExportService.instance.exportCsv(history);
    if (!mounted) return;
    setState(() => _exporting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось экспортировать данные')),
      );
    }
  }
}

// ── LineChart ────────────────────────────────────────────────

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.history,
    required this.unit,
    required this.theme,
  });

  final List<TemperatureValue> history;
  final TemperatureUnit        unit;
  final ThemeData              theme;

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    final spots   = _buildSpots();
    // Минимальный диапазон оси Y — 4 единицы.
    // Если реальный разброс меньше (например, 25.5–25.7),
    // ось расширяется симметрично от середины.
    // Это предотвращает «скачку» графика на весь экран
    // при стабильной температуре.
    const double kMinSpan = 4.0;
    final double dataMin  = _minValue();
    final double dataMax  = _maxValue();
    final double mid      = (dataMin + dataMax) / 2;
    final double span     = (dataMax - dataMin) < kMinSpan
        ? kMinSpan
        : dataMax - dataMin;
    final double pad      = span * 0.1;
    final double minY     = mid - span / 2 - pad;
    final double maxY     = mid + span / 2 + pad;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _yInterval(minY, maxY),
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:   const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 24,
                interval:     _xInterval(),
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}с',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots:           spots,
              isCurved:        true,
              curveSmoothness: 0.2,
              color:           primary,
              barWidth:        2,
              dotData:         const FlDotData(show: false),
              belowBarData:    BarAreaData(
                show:  true,
                color: primary.withValues(alpha: 0.07),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) =>
                LineTooltipItem(
                  '${s.y.toStringAsFixed(1)} ${unit.label}',
                  TextStyle(
                    color:      theme.colorScheme.onPrimary,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    if (history.isEmpty) return [];
    final start = history.first.receivedAt;
    return history.map((v) => FlSpot(
      v.receivedAt.difference(start).inSeconds.toDouble(),
      v.inUnit(unit),
    )).toList();
  }

  double _minValue() =>
      history.map((v) => v.inUnit(unit)).reduce((a, b) => a < b ? a : b);
  double _maxValue() =>
      history.map((v) => v.inUnit(unit)).reduce((a, b) => a > b ? a : b);

  double _yInterval(double mn, double mx) {
    // Подбираем шаг сетки под диапазон оси (с учётом min span)
    final r = mx - mn;
    if (r <= 3)  return 1;
    if (r <= 6)  return 1;
    if (r <= 12) return 2;
    if (r <= 25) return 5;
    return 10;
  }

  double _xInterval() {
    final n = history.length;
    if (n <= 30)  return 10;
    if (n <= 60)  return 20;
    if (n <= 120) return 30;
    return 60;
  }
}

// ── Статистика ───────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.minC,
    required this.maxC,
    required this.avgC,
    required this.unit,
    required this.theme,
  });

  final double?        minC, maxC, avgC;
  final TemperatureUnit unit;
  final ThemeData       theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(label: '↓', value: _fmt(minC), theme: theme),
        _Stat(label: '⌀', value: _fmt(avgC), theme: theme),
        _Stat(label: '↑', value: _fmt(maxC), theme: theme),
      ],
    );
  }

  String _fmt(double? celsius) {
    if (celsius == null) return '—';
    final v = switch (unit) {
      TemperatureUnit.celsius    => celsius,
      TemperatureUnit.fahrenheit => celsius * 9 / 5 + 32,
      TemperatureUnit.kelvin     => celsius + 273.15,
    };
    return '${v.toStringAsFixed(1)} ${unit.label}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String    label;
  final String    value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color:    theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight:   FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── Кнопка управления ────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: enabled ? color.withValues(alpha: 0.12) : null,
        foregroundColor: enabled ? color : null,
        side: enabled
            ? BorderSide(color: color.withValues(alpha: 0.4))
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
