part of '../debtor_repository.dart';

extension DebtorRepositoryTrash on DebtorRepository {
  // 3. ลบรายการและคำนวณยอดหนี้คืน (Revert Balance)
  Future<bool> deleteTransaction(int transactionId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 3.1 ดึงข้อมูล Transaction ที่จะลบก่อน
      final transRes = await _dbService.query(
        'SELECT * FROM debtor_transaction WHERE id = :id FOR UPDATE',
        {'id': transactionId},
      );

      if (transRes.isEmpty) {
        throw Exception('Transaction not found');
      }

      final t = transRes.first;
      if (t['isDeleted'] == 1 || t['isDeleted'] == true) {
        // Already deleted
        await _dbService.execute('ROLLBACK;');
        return true;
      }

      final Decimal amount = Decimal.parse(t['amount'].toString());
      final int customerId = int.tryParse(t['customerId'].toString()) ?? 0;
      final int? orderId = int.tryParse(t['orderId']?.toString() ?? '');
      final String type = t['transactionType'].toString();

      // ✅ 3.1.5 ตรวจสอบสถานะบิลต้นทาง (ห้ามลบถ้าบิลยังอยู่)
      // ต้องตรวจเฉพาะ CREDIT_SALE เท่านั้น (เพราะถ้าบิลยังไม่ยกเลิก ห้ามลบหนี้)
      // แต่ถ้าเป็น DEBT_PAYMENT (ลูกค้ามาจ่ายเงิน) สามารถลบได้เลย เพื่อให้บิลกลับไปค้างชำระ
      if (type == 'CREDIT_SALE' && orderId != null && orderId > 0) {
        final orderRes = await _dbService.query(
          'SELECT status FROM `order` WHERE id = :id',
          {'id': orderId},
        );
        if (orderRes.isNotEmpty) {
          final String status = orderRes.first['status']?.toString() ?? '';
          if (status != 'VOID') {
            await _dbService.execute('ROLLBACK;');
            throw Exception(
                'ไม่สามารถลบรายการได้ กรุณายกเลิกบิลต้นทาง (#$orderId) ก่อน');
          }
        }
      }

      // 3.2 ดึงหนี้ปัจจุบันของลูกค้า
      final custRes = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
        {'id': customerId},
      );

      Decimal currentDebt = Decimal.zero;
      if (custRes.isNotEmpty) {
        currentDebt = Decimal.parse(custRes.first['currentDebt'].toString());
      }

      // 3.3 คำนวณยอดหนี้ใหม่ (ย้อนกลับการกระทำ)
      final Decimal newDebt = currentDebt - amount;

      // 3.4 อัปเดตยอดหนี้ลูกค้า
      await _dbService.execute(
        'UPDATE customer SET currentDebt = :bal WHERE id = :id',
        {'bal': newDebt.toDouble(), 'id': customerId},
      );

      // 3.5 หากเป็นการชำระหนี้ระบุบิล ต้องไปคืนค่ายอดเงินรับให้บิลนั้น
      if (type == 'DEBT_PAYMENT' && orderId != null && orderId > 0) {
        final orderRes = await _dbService.query(
          'SELECT received, status FROM `order` WHERE id = :id FOR UPDATE',
          {'id': orderId},
        );
        if (orderRes.isNotEmpty) {
          final oData = orderRes.first;
          final double currentReceived =
              double.tryParse(oData['received'].toString()) ?? 0.0;
          final double paymentAmount =
              amount.abs().toDouble(); // DEBT_PAYMENT is negative amount
          final double newReceived = currentReceived - paymentAmount;

          String newStatus = oData['status']?.toString() ?? '';
          if (newStatus == 'COMPLETED') {
            newStatus = 'UNPAID';
          }

          await _dbService.execute(
            'UPDATE `order` SET received = :recv, status = :status WHERE id = :id',
            {
              'recv': newReceived < 0 ? 0 : newReceived,
              'status': newStatus,
              'id': orderId
            },
          );
        }
      }

      // 3.5 Soft Delete (ย้ายลงถังขยะ)
      await _dbService.execute(
        '''
        UPDATE debtor_transaction 
        SET isDeleted = 1, deletedAt = NOW(), deleteReason = :reason
        WHERE id = :id
        ''',
        {'id': transactionId, 'reason': 'User Deleted'},
      );

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting transaction: $e');
      return false;
    }
  }

  // 4.1 ดึงรายการที่ลบ (Recycle Bin)
  Future<List<Map<String, dynamic>>> getDeletedTransactions() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Join Customer to get Name
      const sql = '''
        SELECT dt.*, c.firstName, c.lastName 
        FROM debtor_transaction dt
        LEFT JOIN customer c ON dt.customerId = c.id
        WHERE dt.isDeleted = 1
        ORDER BY dt.deletedAt DESC;
      ''';
      return await _dbService.query(sql);
    } catch (e) {
      debugPrint('Error fetching deleted transactions: $e');
      return [];
    }
  }

  // 4.2 กู้คืนรายการ (Restore)
  Future<bool> restoreTransaction(int transactionId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Get Transaction Info including amount
      final transRes = await _dbService.query(
        'SELECT * FROM debtor_transaction WHERE id = :id FOR UPDATE',
        {'id': transactionId},
      );

      if (transRes.isEmpty) throw Exception('Transaction not found');

      final t = transRes.first;
      final Decimal amount =
          Decimal.parse(t['amount'].toString()); // Amount of the Transaction
      final int customerId = int.tryParse(t['customerId'].toString()) ?? 0;

      // 2. Get Current Debt
      final custRes = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
        {'id': customerId},
      );

      Decimal currentDebt = Decimal.zero;
      if (custRes.isNotEmpty) {
        currentDebt = Decimal.parse(custRes.first['currentDebt'].toString());
      }

      // 3. Re-Apply the Transaction
      // ลบรายการ = หนี้เพิ่ม/ลด (Reverse)
      // กู้คืน = กลับไปเป็นเหมือนเดิม (Apply)
      // สูตร: หนี้ใหม่ = หนี้ปัจจุบัน + ยอดTransaction
      final Decimal newDebt = currentDebt + amount;

      // 4. Update Customer Debt
      await _dbService.execute(
        'UPDATE customer SET currentDebt = :bal WHERE id = :id',
        {'bal': newDebt.toDouble(), 'id': customerId},
      );

      // 5. Update Transaction Status
      await _dbService.execute(
        'UPDATE debtor_transaction SET isDeleted = 0, deletedAt = NULL, deleteReason = NULL WHERE id = :id',
        {'id': transactionId},
      );

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error restoring transaction: $e');
      return false;
    }
  }
}
