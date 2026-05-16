import 'dart:async';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'mysql_service.dart';

class NotificationScheduler {
  static final NotificationScheduler _instance =
      NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  Timer? _timer;
  bool _isProcessing = false;

  // Run every 2 minutes
  static const Duration _interval = Duration(minutes: 2);

  void start() {
    if (_timer != null && _timer!.isActive) return;

    debugPrint(
        '⏰ [NotificationScheduler] Starting... (Interval: ${_interval.inMinutes} mins)');

    // Run immediately first
    _runTask();

    _timer = Timer.periodic(_interval, (timer) {
      _runTask();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 [NotificationScheduler] Stopped.');
  }

  Future<void> _runTask() async {
    if (_isProcessing) {
      debugPrint('⏳ [NotificationScheduler] Skipped (Already processing)');
      return;
    }

    _isProcessing = true;
    try {
      final db = MySQLService();
      // Ensure DB is connected before trying
      if (!db.isConnected()) {
        // debugPrint('⚠️ [NotificationScheduler] MySQL not connected. Skipping.');
        return;
      }

      await FirebaseService().processPendingNotifications(db);
    } catch (e) {
      debugPrint('⚠️ [NotificationScheduler] Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> triggerNow() async {
    debugPrint('🔔 [NotificationScheduler] Manual trigger requested.');
    await _runTask();
  }
}
