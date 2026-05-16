import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import '../backup/google_drive_service.dart';

class BackupScheduler {
  static final BackupScheduler _instance = BackupScheduler._internal();
  factory BackupScheduler() => _instance;
  BackupScheduler._internal();

  Timer? _timer;
  final BackupService _backupService = BackupService();
  final GoogleDriveService _driveService = GoogleDriveService();

  // Keys
  static const String keyBackupInterval =
      'backup_interval_type'; // NONE, 30M, 1H, 6H, DAILY, WEEKLY, MONTHLY
  static const String keyBackupDest = 'backup_destination'; // LOCAL, DRIVE
  static const String keyLastBackup = 'last_backup_timestamp';

  Future<void> init() async {
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // Check every 15 minutes
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _checkAndPerformBackup();
    });

    // DELAY the first check on startup to avoid Isolate pressure
    // while the app is still initializing UI/Windows.
    Future.delayed(const Duration(minutes: 2), () {
      _checkAndPerformBackup();
    });
  }

  Future<void> _checkAndPerformBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final intervalType = prefs.getString(keyBackupInterval) ?? 'NONE';
    if (intervalType == 'NONE') return;

    final dest = prefs.getString(keyBackupDest) ?? 'LOCAL';
    final lastBackupMillis = prefs.getInt(keyLastBackup) ?? 0;
    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
    final now = DateTime.now();

    bool shouldBackup = false;

    switch (intervalType) {
      case '30M':
        if (now.difference(lastBackup).inMinutes >= 30) shouldBackup = true;
        break;
      case '1H':
        if (now.difference(lastBackup).inHours >= 1) shouldBackup = true;
        break;
      case '6H':
        if (now.difference(lastBackup).inHours >= 6) shouldBackup = true;
        break;
      case 'DAILY':
        if (now.difference(lastBackup).inHours >= 24) shouldBackup = true;
        break;
      case 'WEEKLY':
        if (now.difference(lastBackup).inDays >= 7) shouldBackup = true;
        break;
      case 'MONTHLY':
        if (now.difference(lastBackup).inDays >= 30) shouldBackup = true;
        break;
    }

    if (shouldBackup) {
      debugPrint('Starting scheduled backup...');
      final file = await _backupService.createBackup();
      if (file != null) {
        if (dest == 'DRIVE') {
          // Implement upload logic
          debugPrint('Uploading backup to Google Drive...');
          final ok = await _driveService.uploadBackup(file);
          if (ok) {
            debugPrint('✅ Google Drive Upload Success');
          } else {
            debugPrint(
                '❌ Drive upload failed (Check Auth/Network). keeping local file.');
          }
        }

        // Update Timestamp
        await prefs.setInt(
            keyLastBackup, DateTime.now().millisecondsSinceEpoch);
        debugPrint('Scheduled backup completed.');

        // Cleanup Old Backups (Retention Policy: Count Based 10 items)
        // ตามที่ขอ: เก็บไว้ 10 รายการล่าสุด วนลบอันเก่าสุด
        const maxKeep = 10;

        if (dest == 'DRIVE') {
          await _driveService.cleanupOldBackups(maxKeep);
        }
        await _backupService.cleanupLocalBackups(maxKeep);
      }
    }
  }
}
