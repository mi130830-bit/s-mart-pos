import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mysql_service.dart';
import 'telegram_service.dart';

class TelegramScheduler {
  static final TelegramScheduler _instance = TelegramScheduler._internal();
  factory TelegramScheduler() => _instance;
  TelegramScheduler._internal();

  Timer? _timer;
  final MySQLService _db = MySQLService();
  final TelegramService _telegram = TelegramService();

  // Key to store the last reported hour (e.g., "2023-10-27 10:00")
  static const String keyLastReportedHour = 'telegram_last_reported_hour';

  // Start the scheduler
  void start() {
    _timer?.cancel();
    // Check every 1 minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndReport();
    });
    // Run check immediately on start
    _checkAndReport();
  }

  void stop() {
    _timer?.cancel();
  }

  bool _isProcessing = false; // ✅ Prevent race condition

  Future<void> _checkAndReport() async {
    if (_isProcessing) return; // ✅ Local Guard
    _isProcessing = true;

    try {
      if (!_db.isConnected()) return; // Wait for DB connection

      final prefs = await SharedPreferences.getInstance();

      // 1. Check if feature is enabled (Check local prefs or DB settings)
      // Since SettingsService syncs DB to Prefs, we can trust Prefs for "Enabled" status
      final isEnabled = _getBool(prefs, TelegramService.keyNotifyHourlySales);
      if (!isEnabled) return;

      final now = DateTime.now();

      // We report for the "Previous Hour".
      final currentHour = DateTime(now.year, now.month, now.day, now.hour);
      final lastPossibleReportHour =
          currentHour.subtract(const Duration(hours: 1));
      final targetHourStr = lastPossibleReportHour.toIso8601String();

      // -------------------------------------------------------------
      // ✅ DISTRIBUTED LOCK MECHANISM (Fix for Multi-Device Duplicates)
      // -------------------------------------------------------------
      // 1. Ensure the key exists
      await _db.execute(
          "INSERT IGNORE INTO system_settings (setting_key, setting_value) VALUES (:key, :val)",
          {'key': keyLastReportedHour, 'val': ''});

      // 2. Try to seize the lock ATOMICALLY
      // Only one client will succeed in updating the value from "Old" to "New".
      // If value is already "New", affectedRows will be 0.
      final result = await _db.execute(
          "UPDATE system_settings SET setting_value = :newVal WHERE setting_key = :key AND setting_value != :checkVal",
          {
            'newVal': targetHourStr,
            'key': keyLastReportedHour,
            'checkVal': targetHourStr
          });

      if (result.affectedRows == BigInt.zero) {
        // Already reported by another device or this device previously.
        return;
      }

      // ✅ If we get here, WE won the race. Send the report.
      // -------------------------------------------------------------

      // Also update local prefs just in case, though DB is the source of truth now
      await prefs.setString(keyLastReportedHour, targetHourStr);

      // Define the range to query
      final start = lastPossibleReportHour;
      final end = currentHour;

      await _sendReport(start, end);
    } catch (e) {
      debugPrint('Telegram Scheduler Error: $e');
    } finally {
      _isProcessing = false; // ✅ Release local lock
    }
  }

  Future<void> _sendReport(DateTime start, DateTime end) async {
    // 1. Hourly Stats
    final hourlyStats = await _querySales(start, end);

    // 2. Daily Stats (From start of day 00:00 to end of reported hour)
    // User requested "Whole Day Data"
    final startOfDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final dailyStats = await _querySales(startOfDay, end);

    // Format Message
    final hourLabel =
        '${start.hour.toString().padLeft(2, '0')}:00 - ${end.hour.toString().padLeft(2, '0')}:00';

    final msg = '''
⏰ *รายงานยอดขายรายชั่วโมง* (Hourly Sales)
━━━━━━━━━━━━━━━━━━
📅 *ช่วงเวลา:* $hourLabel
💰 *ยอดชั่วโมงนี้:* ${hourlyStats.total.toStringAsFixed(2)} บาท (${hourlyStats.count} บิล)

📈 *ยอดสะสมวันนี้* (ถึง ${end.hour}:00)
━━━━━━━━━━━━━━━━━━
💰 *ยอดรวม:* ${dailyStats.total.toStringAsFixed(2)} บาท
📄 *บิลรวม:* ${dailyStats.count} ใบ
━━━━━━━━━━━━━━━━━━
''';

    await _telegram.sendMessage(msg);
  }

  Future<SalesStats> _querySales(DateTime start, DateTime end) async {
    const sql = '''
      SELECT 
        COUNT(*) as count, 
        COALESCE(SUM(grandTotal), 0) as total 
      FROM `order` 
      WHERE status = 'COMPLETED' 
      AND createdAt >= :start 
      AND createdAt < :end
    ''';

    final results = await _db.query(sql, {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    });

    if (results.isEmpty) return SalesStats(0, 0.0);

    final row = results.first;
    final count = int.tryParse(row['count'].toString()) ?? 0;
    final total = double.tryParse(row['total'].toString()) ?? 0.0;

    return SalesStats(count, total);
  }

  bool _getBool(SharedPreferences prefs, String key) {
    try {
      final val = prefs.get(key);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return false;
    } catch (_) {
      return false;
    }
  }
}

class SalesStats {
  final int count;
  final double total;
  SalesStats(this.count, this.total);
}
