import 'dart:async';
import '../firestore_rest_service.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../models/hr/attendance_log.dart';
import '../logger_service.dart';
import 'package:intl/intl.dart';

class AttendanceSyncService {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      syncAttendanceFromCloud();
    });
    // Trigger immediately on start
    syncAttendanceFromCloud();
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
    LoggerService.info('AttendanceSync', 'Starting attendance sync from Firestore...');

    try {
      final result = await FirestoreRestService().getAttendanceLogs();
      if (!result.isSuccess || result.data == null) {
        LoggerService.error('AttendanceSync', 'Failed to fetch attendance logs: ${result.errorMessage}');
        return;
      }

      final logs = result.data!;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (var logData in logs) {
        final docId = logData['name']?.toString().split('/').last ?? '';
        final userId = logData['user_id']?.toString() ?? '';
        final date = logData['date']?.toString() ?? '';
        final checkInStr = logData['check_in_time']?.toString();
        final checkOutStr = logData['check_out_time']?.toString();
        final tempOutStr = logData['temp_out_time']?.toString();
        final backToWorkStr = logData['back_to_work_time']?.toString();
        
        // Find employee by firebase_uid
        final emp = await _employeeRepo.getByFirebaseUid(userId);
        if (emp != null) {
          final attendanceLog = AttendanceLog(
            id: 0,
            employeeId: emp.id,
            date: DateTime.tryParse(date) ?? DateTime.now(),
            clockIn: checkInStr != null ? DateTime.tryParse(checkInStr) : null,
            clockOut: checkOutStr != null ? DateTime.tryParse(checkOutStr) : null,
            tempOut: tempOutStr != null ? DateTime.tryParse(tempOutStr) : null,
            backToWork: backToWorkStr != null ? DateTime.tryParse(backToWorkStr) : null,
            method: 'MOBILE_GPS',
            latitude: double.tryParse(logData['check_in_lat']?.toString() ?? ''),
            longitude: double.tryParse(logData['check_in_lng']?.toString() ?? ''),
            status: logData['status']?.toString() ?? 'PRESENT',
          );

          // Save to MySQL
          await _attendanceRepo.syncAttendance(attendanceLog);
          LoggerService.info('AttendanceSync', 'Synced attendance for ${emp.displayName} on $date');

          // Delete from Firestore if it's older than today (ลบตัวเองภายในวัน)
          // หรือถ้าวันที่ใน log ไม่ใช่วันนี้ ก็ลบทิ้งเลยเพื่อประหยัดพื้นที่
          if (date != todayStr && docId.isNotEmpty) {
            await FirestoreRestService.deleteDocument('attendance_logs', docId);
            LoggerService.info('AttendanceSync', 'Deleted old attendance log from Firestore: $docId');
          }
        } else {
          LoggerService.warning('AttendanceSync', 'Employee not found for firebase_uid: $userId');
        }
      }
    } catch (e) {
      LoggerService.error('AttendanceSync', 'Error syncing attendance', e);
    } finally {
      _isSyncing = false;
    }
  }
}
