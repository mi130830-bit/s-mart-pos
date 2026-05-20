part of '../customer_repository.dart';

extension CustomerRepositoryTrash on CustomerRepository {
  Future<bool> deleteCustomer(int id, {String reason = ''}) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      // Soft Delete
      await _dbService.execute(
        '''
        UPDATE customer SET 
          isDeleted = 1, 
          deleteReason = :reason, 
          deletedAt = NOW(),
          line_user_id = NULL,
          line_display_name = NULL, 
          line_picture_url = NULL
        WHERE id = :id
        ''',
        {'id': id, 'reason': reason},
      );

      await _activityRepo.log(
          action: 'DELETE_CUSTOMER',
          details: 'ลบลูกค้า ID: $id (Soft Delete) สาเหตุ: $reason');
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }

  Future<bool> restoreCustomer(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        'UPDATE customer SET isDeleted = 0, deletedAt = NULL, deleteReason = NULL WHERE id = :id',
        {'id': id},
      );

      await _activityRepo.log(
          action: 'RESTORE_CUSTOMER', details: 'กู้คืนลูกค้า ID: $id');
      return true;
    } catch (e) {
      debugPrint('Error restoring customer: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDeletedCustomers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      return await _dbService.query('''
        SELECT * FROM customer 
        WHERE isDeleted = 1 
          AND deletedAt >= DATE_SUB(NOW(), INTERVAL 15 DAY)
        ORDER BY deletedAt DESC
      ''');
    } catch (e) {
      return [];
    }
  }

  Future<void> cleanOldDeletedCustomers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ✅ Update: Only delete customers that have NO transactions or orders
      // to avoid Foreign Key Constraint Fails [1451]
      final sql = '''
        DELETE FROM customer 
        WHERE isDeleted = 1 
          AND deletedAt < DATE_SUB(NOW(), INTERVAL 15 DAY)
          AND id NOT IN (SELECT DISTINCT customerId FROM debtor_transaction)
          AND id NOT IN (SELECT DISTINCT customerId FROM `order`)
      ''';
      final res = await _dbService.execute(sql);

      if (res.affectedRows.toInt() > 0) {
        await _activityRepo.log(
            action: 'AUTO_CLEAN',
            details:
                'ลบลูกค้าถาวร ${res.affectedRows} รายการ (เฉพาะที่ไม่ถูกใช้งาน)');
      }
    } catch (e) {
      debugPrint('Error cleaning customers: $e');
    }
  }
}
