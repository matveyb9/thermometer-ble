// ─────────────────────────────────────────────────────────────
//  lib/services/export_service.dart
//  Экспорт истории температуры в CSV через системный диалог
// ─────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/temperature.dart';

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Формирует CSV из [history] и открывает системный диалог «Поделиться».
  /// Возвращает true если файл успешно создан и передан системе.
  Future<bool> exportCsv(List<TemperatureValue> history) async {
    if (history.isEmpty) return false;

    try {
      final csv = _buildCsv(history);
      final file = await _writeTempFile(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Thermometer export',
      );
      return true;
    } catch (e) {
      debugPrint('[ExportService] export error: $e');
      return false;
    }
  }

  // ── Приватные ────────────────────────────────────────────

  String _buildCsv(List<TemperatureValue> history) {
    final buf = StringBuffer();
    // Заголовок
    buf.writeln('Timestamp,Celsius,Fahrenheit,Kelvin');
    // Строки
    for (final v in history) {
      final ts = _formatTimestamp(v.receivedAt);
      buf.writeln(
        '$ts,'
        '${v.celsius.toStringAsFixed(2)},'
        '${v.fahrenheit.toStringAsFixed(2)},'
        '${v.kelvin.toStringAsFixed(2)}',
      );
    }
    return buf.toString();
  }

  String _formatTimestamp(DateTime dt) {
    final y  = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final h  = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s  = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  Future<File> _writeTempFile(String content) async {
    final dir  = await getTemporaryDirectory();
    final name = 'thermometer_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(content, flush: true);
    return file;
  }
}
