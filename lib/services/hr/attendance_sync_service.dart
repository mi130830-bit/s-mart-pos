import 'dart:async';
import '../logger_service.dart';

class AttendanceSyncService {
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer?.cancel();
    LoggerService.info('AttendanceSync', 'Firestore polling disabled by Phase 3 architecture.');
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  Future<void> syncAttendanceFromCloud({bool force = false}) async {
    // final now = DateTime.now();
    
    if (!force) {
      // วันอาทิตย์ร้านปิด ไม่ต้องเช็ค (ปิดชั่วคราวให้เทส)
      // if (now.weekday == DateTime.sunday) return;
      
      // เริ่มเช็คตั้งแต่ 7.00 น. ถึง 17.00 น. (ปิดชั่วคราวให้เทส)
      // if (now.hour < 7) return;
      // if (now.hour > 17 || (now.hour == 17 && now.minute > 5)) return;
    }

    if (_isSyncing) return;
    _isSyncing = true;
    LoggerService.info('AttendanceSync', 'Firestore syncFromCloud is disabled (Phase 3). Data comes directly from S-Link API now.');

    try {
      // Disabled
      // }
    } catch (e) {
      LoggerService.error('AttendanceSync', 'Error syncing attendance', e);
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes the current day's attendance log for the specified employee from MySQL to Firestore.
  /// This ensures that changes made via Fingerprint or PIN on POS Desktop are immediately visible in S-Link.
  Future<void> syncAttendanceToCloud(int employeeId) async {
    LoggerService.info('AttendanceSync', 'Firestore syncToCloud is disabled. Mobile will fetch directly from API.');
  }
}
