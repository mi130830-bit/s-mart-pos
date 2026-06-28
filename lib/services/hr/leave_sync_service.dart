import 'dart:async';
import '../firestore_rest_service.dart';
import '../logger_service.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../repositories/hr/leave_repository.dart';
import '../../models/hr/leave_request.dart';

class LeaveSyncService {
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(hours: 4), (timer) {
      syncLeaveRequestsFromCloud();
    });
    // Trigger immediately on start
    syncLeaveRequestsFromCloud();
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  Future<void> syncLeaveRequestsFromCloud() async {
    if (_isSyncing) return;
    _isSyncing = true;
    LoggerService.info('LeaveSync', 'Starting leave requests sync from Firestore...');

    try {
      final result = await FirestoreRestService().getLeaveRequests();
      if (!result.isSuccess || result.data == null) {
        LoggerService.error('LeaveSync', 'Failed to fetch leave requests: ${result.errorMessage}');
        return;
      }

      final requests = result.data!;
      LoggerService.info('LeaveSync', '>>> Fetched ${requests.length} documents from Firestore holiday_logs');

      for (var reqData in requests) {
        // DEBUG: แสดง keys ทั้งหมดที่ได้จาก _parseDocument
        LoggerService.debug('LeaveSync', '>>> Doc keys: ${reqData.keys.toList()}');
        LoggerService.debug('LeaveSync', '>>> Doc data: $reqData');

        // _parseDocument เก็บ Document ID ไว้ในคีย์ 'id'
        final docId = reqData['id']?.toString() ?? '';
        final syncedToSql = reqData['synced_to_sql'] == true;

        LoggerService.debug('LeaveSync', '>>> docId=$docId, synced_to_sql=$syncedToSql (raw=${reqData['synced_to_sql']})');

        if (syncedToSql) {
          LoggerService.debug('LeaveSync', '>>> SKIP: already synced');
          continue;
        }
        if (docId.isEmpty) {
          LoggerService.warning('LeaveSync', '>>> SKIP: Empty docId');
          continue;
        }

        final firebaseUidOrId = reqData['employee_id']?.toString() ?? '';
        final userName = reqData['user_name']?.toString() ?? '';
        LoggerService.debug('LeaveSync', '>>> Looking for employee: firebaseUid/id="$firebaseUidOrId", user_name="$userName"');

        var emp = await _employeeRepo.getByFirebaseUid(firebaseUidOrId);
        LoggerService.debug('LeaveSync', '>>> getByFirebaseUid("$firebaseUidOrId") => ${emp != null ? "FOUND id=${emp.id}" : "NOT FOUND"}');
        
        // Fallback 1: Integer ID
        if (emp == null) {
          final parsedId = int.tryParse(firebaseUidOrId);
          if (parsedId != null) {
            emp = await _employeeRepo.getById(parsedId);
            LoggerService.debug('LeaveSync', '>>> getById($parsedId) => ${emp != null ? "FOUND id=${emp.id}" : "NOT FOUND"}');
          }
        }

        // Fallback 2: Name
        if (emp == null && userName.isNotEmpty) {
          emp = await _employeeRepo.getByName(userName);
          LoggerService.debug('LeaveSync', '>>> getByName("$userName") => ${emp != null ? "FOUND id=${emp.id}" : "NOT FOUND"}');
        }
        
        final employeeId = emp?.id ?? 0;

        if (employeeId == 0) {
          LoggerService.warning('LeaveSync', '>>> SKIP: Employee not found for "$firebaseUidOrId" / "$userName"');
          continue; // Skip this record, DO NOT mark as synced_to_sql
        }

        LoggerService.info('LeaveSync', '>>> Processing leave for employeeId=$employeeId, docId=$docId');

        final action = reqData['action']?.toString() ?? '';
        final status = reqData['status']?.toString().toUpperCase() ?? 'PENDING';
        final leaveType = reqData['leave_type']?.toString() ?? 'PERSONAL';
        final leaveFormat = reqData['leave_format']?.toString() ?? 'FULL_DAY';
        final totalDays = double.tryParse(reqData['total_days']?.toString() ?? '0') ?? 0.0;
        final reason = reqData['reason']?.toString() ?? '';

        final startDateStr = reqData['start_date']?.toString();
        final endDateStr = reqData['end_date']?.toString();
        final startDate = startDateStr != null ? (DateTime.tryParse(startDateStr) ?? DateTime.now()) : DateTime.now();
        final endDate = endDateStr != null ? (DateTime.tryParse(endDateStr) ?? startDate) : startDate;

        // ดึงประวัติใบลางานของพนักงานคนนี้
        final history = await LeaveRepository().getByEmployee(employeeId, year: startDate.year);

        if (action == 'holiday_cancel' || status == 'CANCELLED') {
          // ค้นหาใบลาที่ตรงกันเพื่อยกเลิก
          final targetLeave = history.firstWhere(
            (l) => l.startDate.year == startDate.year && 
                   l.startDate.month == startDate.month &&
                   l.startDate.day == startDate.day &&
                   l.leaveType == leaveType &&
                   l.status != 'CANCELLED',
            orElse: () => LeaveRequest(id: 0, employeeId: 0, leaveType: '', startDate: DateTime.now(), endDate: DateTime.now(), totalDays: 0, status: ''),
          );

          if (targetLeave.id > 0) {
            await LeaveRepository().cancel(targetLeave.id);
            LoggerService.info('LeaveSync', '>>> Cancelled leave request for Emp: $employeeId');
          }
        } else {
          // กรณีเป็น holiday_start หรือรายการลาใหม่
          // ป้องกันการบันทึกซ้ำซ้อน (Duplicate check)
          final isDuplicate = history.any((l) => 
            l.startDate.year == startDate.year &&
            l.startDate.month == startDate.month &&
            l.startDate.day == startDate.day &&
            l.leaveType == leaveType &&
            l.status != 'CANCELLED'
          );

          if (isDuplicate) {
            LoggerService.warning('LeaveSync', '>>> Duplicate detected for Emp: $employeeId (Date: $startDate). Skipping insertion.');
          } else {
            // สร้างใบลาใหม่
            final newLeave = LeaveRequest(
              id: 0,
              employeeId: employeeId,
              leaveType: leaveType,
              leaveFormat: leaveFormat,
              startDate: startDate,
              endDate: endDate,
              totalDays: totalDays,
              reason: reason,
              status: status,
            );
            final insertedId = await LeaveRepository().create(newLeave);
            LoggerService.info('LeaveSync', '>>> INSERTED leave id=$insertedId for Emp: $employeeId (status=$status)');

            if (status == 'APPROVED') {
              await LeaveRepository().approve(insertedId, 1);
            } else if (status == 'REJECTED') {
              await LeaveRepository().reject(insertedId, 'Rejected from mobile');
            }
          }
        }

        // อัปเดตสถานะใน Firestore ว่าดึงลง SQL แล้ว
        await FirestoreRestService.updateDocument('holiday_logs', docId, {
          'synced_to_sql': true,
        });
        LoggerService.info('LeaveSync', '>>> Marked docId=$docId as synced_to_sql=true');
      }

      LoggerService.info('LeaveSync', '>>> Sync completed successfully');
    } catch (e, stack) {
      LoggerService.error('LeaveSync', 'Error syncing leave requests: $e\n$stack');
    } finally {
      _isSyncing = false;
    }
  }
}
