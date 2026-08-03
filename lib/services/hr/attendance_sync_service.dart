import 'dart:async';
import '../firestore_rest_service.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../models/hr/attendance_log.dart';
import '../logger_service.dart';
import 'package:intl/intl.dart';
import '../../models/hr/employee_profile.dart';

class AttendanceSyncService {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(hours: 4), (timer) {
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
        final docId = logData['id']?.toString() ?? '';
        final userId = logData['user_id']?.toString() ?? '';
        final date = logData['date']?.toString() ?? '';
        final checkInStr = logData['check_in_time']?.toString();
        final checkOutStr = logData['check_out_time']?.toString();
        final tempOutStr = logData['temp_out_time']?.toString();
        final backToWorkStr = logData['back_to_work_time']?.toString();
        
        // Helper for parsing time strings that might only be time (e.g., "09:00:00")
        DateTime? parseTimeFallback(String? timeStr, String baseDate) {
          if (timeStr == null || timeStr.isEmpty) return null;
          final dt = DateTime.tryParse(timeStr);
          if (dt != null) return dt;
          final combined = DateTime.tryParse('$baseDate $timeStr');
          if (combined != null) return combined;
          // Try adding seconds if it's just "HH:mm"
          if (timeStr.length <= 5 && timeStr.contains(':')) {
            final withSeconds = DateTime.tryParse('$baseDate $timeStr:00');
            if (withSeconds != null) return withSeconds;
          }
          return null;
        }

        // Find employee by user_id
        final empId = int.tryParse(userId);
        EmployeeProfile? emp;
        if (empId != null) {
            emp = await _employeeRepo.getByUserId(empId);
        }
        if (emp != null) {
          final attendanceLog = AttendanceLog(
            id: 0,
            employeeId: emp.id,
            date: DateTime.tryParse(date) ?? DateTime.now(),
            clockIn: parseTimeFallback(checkInStr, date),
            clockOut: parseTimeFallback(checkOutStr, date),
            tempOut: parseTimeFallback(tempOutStr, date),
            backToWork: parseTimeFallback(backToWorkStr, date),
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

  /// Pushes the current day's attendance log for the specified employee from MySQL to Firestore.
  /// This ensures that changes made via Fingerprint or PIN on POS Desktop are immediately visible in S-Link.
  Future<void> syncAttendanceToCloud(int employeeId) async {
    try {
      final employee = await _employeeRepo.getById(employeeId);
      if (employee == null || employee.userId == null || employee.userId! <= 0) {
        LoggerService.warning('AttendanceSync', 'Skipping syncToCloud: Employee missing user_id');
        return;
      }

      final todayLog = await _attendanceRepo.getTodayLogByEmployee(employeeId);
      if (todayLog == null) {
        return; // No log for today to sync
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(todayLog.date);
      // 🔥 Document ID matches S-Link format: userId_date
      final docId = '${employee.userId}_$dateStr';

      final Map<String, dynamic> data = {
        'user_id': employee.userId.toString(),
        'user_name': employee.displayName ?? '',
        'date': dateStr,
        'status': todayLog.status,
      };

      if (todayLog.clockIn != null) data['check_in_time'] = todayLog.clockIn!.toIso8601String();
      if (todayLog.latitude != null) data['check_in_lat'] = todayLog.latitude;
      if (todayLog.longitude != null) data['check_in_lng'] = todayLog.longitude;
      if (todayLog.clockOut != null) data['check_out_time'] = todayLog.clockOut!.toIso8601String();

      // For S-Link, map the first available temp leave to the single temp_out UI state.
      if (todayLog.tempOut != null) data['temp_out_time'] = todayLog.tempOut!.toIso8601String();
      if (todayLog.backToWork != null) data['back_to_work_time'] = todayLog.backToWork!.toIso8601String();

      // Using setDocumentFull (PATCH without updateMask), which creates or overwrites the doc completely
      await FirestoreRestService.setDocumentFull('attendance_logs', docId, data);
      LoggerService.info('AttendanceSync', 'Successfully synced attendance to cloud for ${employee.displayName}');
    } catch (e) {
      LoggerService.error('AttendanceSync', 'Error syncing attendance to cloud for employee #$employeeId', e);
    }
  }
}
