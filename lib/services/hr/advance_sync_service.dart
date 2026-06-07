import 'dart:async';
import '../firestore_rest_service.dart';
import '../../repositories/hr/advance_repository.dart';
import '../../models/hr/advance_payment.dart';
import '../logger_service.dart';

import '../../repositories/hr/employee_repository.dart';

class AdvanceSyncService {
  final AdvanceRepository _advanceRepo = AdvanceRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      syncAdvanceRequestsFromCloud();
    });
    // Trigger immediately on start
    syncAdvanceRequestsFromCloud();
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  Future<void> syncAdvanceRequestsFromCloud() async {
    if (_isSyncing) return;
    _isSyncing = true;
    LoggerService.info('AdvanceSync', 'Starting advance money requests sync from Firestore...');

    try {
      final result = await FirestoreRestService().getAdvanceMoneyRequests();
      if (!result.isSuccess || result.data == null) {
        LoggerService.error('AdvanceSync', 'Failed to fetch advance money requests: ${result.errorMessage}');
        return;
      }

      final requests = result.data!;

      for (var reqData in requests) {
        final docId = reqData['name']?.toString().split('/').last ?? '';
        final status = reqData['status']?.toString() ?? '';
        final syncedToSql = reqData['synced_to_sql'] == true;

        // ดึงเฉพาะที่ยังไม่ได้ sync ลง SQL
        if (syncedToSql) continue;

        // ใน POS เราจะสนใจแค่รายการที่ถูก 'approved' หรือ 'rejected' ไปแล้ว
        // หากต้องการเก็บ history ของ pending ด้วย ก็ให้ sync ได้เลย 
        // แต่เพื่อความง่าย เราจะ sync ลง SQL เป็นประวัติเลยไม่ว่าจะ pending/approved/rejected
        
        final firebaseUid = reqData['employee_id']?.toString() ?? '';
        final emp = await _employeeRepo.getByFirebaseUid(firebaseUid);
        final employeeId = emp?.id ?? 0;
        
        final amountStr = reqData['amount']?.toString() ?? '0';
        final amount = double.tryParse(amountStr) ?? 0.0;
        final installmentAmountStr = reqData['installment_amount']?.toString();
        final installmentAmount = installmentAmountStr != null ? double.tryParse(installmentAmountStr) : null;
        final reason = reqData['reason']?.toString() ?? '';
        final createdAtStr = reqData['created_at']?.toString();
        
        if (employeeId > 0 && docId.isNotEmpty) {
          // Status mapping: S-Link uses 'pending', 'approved', 'rejected'
          // POS uses 'PENDING', 'APPROVED', 'REJECTED'
          String posStatus = status.toUpperCase();
          if (!['PENDING', 'APPROVED', 'REJECTED'].contains(posStatus)) {
            posStatus = 'PENDING';
          }

          final advance = AdvancePayment(
            id: 0,
            employeeId: employeeId,
            amount: amount,
            requestDate: createdAtStr != null ? (DateTime.tryParse(createdAtStr) ?? DateTime.now()) : DateTime.now(),
            reason: reason,
            installmentAmount: installmentAmount,
            status: posStatus,
            remainingAmount: posStatus == 'APPROVED' ? amount : 0.0,
            approvedBy: posStatus == 'APPROVED' ? 1 : null, // 1 for System/Admin
            approvedAt: posStatus == 'APPROVED' ? DateTime.now() : null,
          );

          // ป้องกันการบันทึกซ้ำซ้อน (Duplicate check)
          // เช็คว่ามีข้อมูลเบิกเงินของพนักงานคนนี้ ที่ยอดเงินเท่ากัน เหตุผลเหมือนกัน และขอในวันเดียวกันหรือไม่
          final history = await _advanceRepo.getHistory(employeeId);
          final isDuplicate = history.any((adv) => 
            adv.amount == amount && 
            adv.reason == reason && 
            adv.status == posStatus &&
            adv.requestDate.year == advance.requestDate.year &&
            adv.requestDate.month == advance.requestDate.month &&
            adv.requestDate.day == advance.requestDate.day
          );

          if (isDuplicate) {
            LoggerService.warning('AdvanceSync', 'Duplicate detected for Emp: $employeeId (Amt: $amount). Skipping insertion.');
            await FirestoreRestService.updateDocument('advance_money_requests', docId, {
              'synced_to_sql': true,
            });
            continue;
          }

          // Save to MySQL
          final insertedId = await _advanceRepo.create(advance);
          
          if (posStatus == 'APPROVED') {
            await _advanceRepo.approve(insertedId, 1);
          } else if (posStatus == 'REJECTED') {
            await _advanceRepo.reject(insertedId);
          }

          LoggerService.info('AdvanceSync', 'Synced advance request to MySQL for Emp: $employeeId (Status: $posStatus)');

          // Update Firebase flag to prevent duplicate sync
          // เราเซ็ตให้ synced_to_sql = true แต่ไม่ลบทิ้ง เพื่อให้ S-Link ยังดูประวัติได้ชั่วคราว (3 วัน)
          await FirestoreRestService.updateDocument('advance_money_requests', docId, {
            'synced_to_sql': true,
          });
        }
      }
    } catch (e) {
      LoggerService.error('AdvanceSync', 'Error syncing advance requests', e);
    } finally {
      _isSyncing = false;
    }
  }
}
