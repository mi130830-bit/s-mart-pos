import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/debtor_transaction.dart';
import '../models/customer.dart';
import '../models/outstanding_bill.dart';

class DebtorRepository {
  final MySQLService _dbService = MySQLService();

  // 1. บันทึกหนี้ใหม่ (ใช้ตอนจบการขายแบบ "เชื่อ")
  Future<bool> addDebt({
    required int customerId,
    required int orderId,
    required double amount,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    // เริ่ม Transaction เพื่อความปลอดภัยของข้อมูล
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1.1 อัปเดตยอดหนี้ลูกค้า (Atomic Update)
      // เรายังโหลดมาเพื่อบันทึก balanceBefore/After ใน transaction table
      // แต่ลดการพึ่งพา logic ใน Dart สำหรับยอดรวมสุดท้าย
      final res = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
        {'id': customerId},
      );

      double currentDebt = 0.0;
      if (res.isNotEmpty) {
        currentDebt =
            double.tryParse(res.first['currentDebt'].toString()) ?? 0.0;
      }

      final double balanceBefore = currentDebt;
      final double balanceAfter = currentDebt + amount;

      await _dbService.execute(
        'UPDATE customer SET currentDebt = currentDebt + :amt WHERE id = :id',
        {'amt': amount, 'id': customerId},
      );

      // 1.2 บันทึกประวัติ Transaction
      const sql = '''
        INSERT INTO debtor_transaction 
        (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
        VALUES (:cid, :oid, 'CREDIT_SALE', :amt, :bBefore, :bAfter, :note, NOW());
      ''';

      await _dbService.execute(sql, {
        'cid': customerId,
        'oid': orderId,
        'amt': amount,
        'bBefore': balanceBefore,
        'bAfter': balanceAfter,
        'note': 'ขายเชื่อจากบิล #$orderId',
      });

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error adding debt: $e');
      return false;
    }
  }

  // 2. บันทึกการชำระหนี้ (ลูกค้าเอาเงินมาจ่าย)
  Future<bool> payDebt({
    required int customerId,
    required double amount, // ยอดที่ลูกค้าจ่ายมา
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      final res = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
        {'id': customerId},
      );

      double currentDebt = 0.0;
      if (res.isNotEmpty) {
        currentDebt =
            double.tryParse(res.first['currentDebt'].toString()) ?? 0.0;
      }

      final double balanceBefore = currentDebt;
      final double balanceAfter = currentDebt - amount;

      // 2.1 อัปเดตยอดหนี้ลูกค้า (Atomic Update)
      await _dbService.execute(
        'UPDATE customer SET currentDebt = currentDebt - :amt WHERE id = :id',
        {'amt': amount, 'id': customerId},
      );

      // 2.2 บันทึกประวัติ Transaction (ยอดติดลบ = ลดหนี้)
      const sql = '''
        INSERT INTO debtor_transaction 
        (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
        VALUES (:cid, NULL, 'PAYMENT', :amt, :bBefore, :bAfter, 'ชำระหนี้', NOW());
      ''';

      await _dbService.execute(sql, {
        'cid': customerId,
        'amt': -amount, // บันทึกเป็นลบ
        'bBefore': balanceBefore,
        'bAfter': balanceAfter,
      });

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error paying debt: $e');
      return false;
    }
  }

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
      final double amount = double.tryParse(t['amount'].toString()) ?? 0.0;
      final int customerId = int.tryParse(t['customerId'].toString()) ?? 0;

      // 3.2 ดึงหนี้ปัจจุบันของลูกค้า
      final custRes = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
        {'id': customerId},
      );

      double currentDebt = 0.0;
      if (custRes.isNotEmpty) {
        currentDebt =
            double.tryParse(custRes.first['currentDebt'].toString()) ?? 0.0;
      }

      // 3.3 คำนวณยอดหนี้ใหม่ (ย้อนกลับการกระทำ)
      // สูตร: หนี้ใหม่ = หนี้ปัจจุบัน - ยอดTransaction
      // - ถ้าลบ "ซื้อเชื่อ" (ยอดบวก) -> หนี้จะลดลง (ถูกต้อง)
      // - ถ้าลบ "จ่ายหนี้" (ยอดลบ) -> หนี้จะเพิ่มขึ้น (ลบด้วยลบเป็นบวก -> ถูกต้อง)
      final double newDebt = currentDebt - amount;

      // 3.4 อัปเดตยอดหนี้ลูกค้า
      await _dbService.execute(
        'UPDATE customer SET currentDebt = :bal WHERE id = :id',
        {'bal': newDebt, 'id': customerId},
      );

      // 3.5 ลบรายการออกจาก Transaction
      await _dbService.execute(
        'DELETE FROM debtor_transaction WHERE id = :id',
        {'id': transactionId},
      );

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting transaction: $e');
      return false;
    }
  }

  // 4. ดึงประวัติลูกหนี้รายคน
  Future<List<DebtorTransaction>> getDebtorHistory(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT * FROM debtor_transaction 
        WHERE customerId = :id 
        ORDER BY createdAt DESC;
      ''';
      final results = await _dbService.query(sql, {'id': customerId});
      return results.map((r) => DebtorTransaction.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching debtor history: $e');
      return [];
    }
  }

  // 5. ดึงรายชื่อลูกหนี้ทั้งหมด (ที่มีหนี้ค้าง > 0)
  Future<List<Customer>> getActiveDebtors() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ดึงลูกค้าที่มีหนี้มากกว่า 0 (0.01 เพื่อกัน Error ทศนิยม)
      // ดึงลูกค้าที่มีหนี้ > 0 และเรียงตามความเคลื่อนไหวล่าสุด
      const sql = '''
        SELECT c.*, MAX(dt.createdAt) as lastActivity
        FROM customer c
        LEFT JOIN debtor_transaction dt ON c.id = dt.customerId
        WHERE c.currentDebt > 0.01
        GROUP BY c.id
        ORDER BY lastActivity DESC;
      ''';
      final results = await _dbService.query(sql);
      return results.map((r) => Customer.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching active debtors: $e');
      return [];
    }
  }

  // 6. ดึงรายการขายเชื่อทั้งหมด (สำหรับแสดงผลแบบ List บิล)
  // เน้นเฉพาะลูกค้าที่มีหนี้ค้างอยู่
  // 6. ดึงรายการขายเชื่อทั้งหมด (สำหรับแสดงผลแบบ List บิล)
  // ปรับปรุง: ดึงจากตาราง debtor_transaction (source of truth ของหนี้) แทนตาราง order
  Future<List<OutstandingBill>> getOutstandingCreditSales() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    // Ensure columns exist to prevent errors
    await _dbService.ensureDebtorTransactionColumns();
    try {
      // ดึงเฉพาะรายการที่เป็นการขายเชื่อ (CREDIT_SALE) จากตารางบัญชีหนี้เท่านั้น
      const sql = '''
        SELECT 
          dt.orderId as orderId,
          dt.customerId,
          COALESCE(o.grandTotal, dt.amount) as amount,
          COALESCE(o.received, 0) as received,
          (COALESCE(o.grandTotal, dt.amount) - COALESCE(o.received, 0)) as remaining,
          dt.createdAt,
          IFNULL(c.firstName, 'ลูกค้าทั่วไป') as firstName,
          IFNULL(c.lastName, '') as lastName,
          IFNULL(c.phone, '-') as phone,
          IFNULL(c.currentDebt, 0) as currentDebt,
          'CREDIT' as status
        FROM debtor_transaction dt
        LEFT JOIN `order` o ON dt.orderId = o.id
        LEFT JOIN customer c ON dt.customerId = c.id
        WHERE dt.transactionType = 'CREDIT_SALE'
          AND (COALESCE(o.grandTotal, dt.amount) - COALESCE(o.received, 0)) > 0.01
        ORDER BY dt.createdAt DESC;
      ''';

      final results = await _dbService.query(sql);
      debugPrint(
          'DebtorRepository: Found ${results.length} items (Source: Ledger Only)');
      return results.map((r) => OutstandingBill.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching outstanding credit sales: $e');
      return [];
    }
  }

  // 7. ชำระเงินรายบิล (Pay Specific Bill)
  Future<bool> paySpecificBill({
    required int orderId,
    required double amount,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 7.1 ดึงข้อมูลบิลปัจจุบัน
      final orderRes = await _dbService.query(
        'SELECT customerId, grandTotal, received FROM `order` WHERE id = :id FOR UPDATE',
        {'id': orderId},
      );

      if (orderRes.isEmpty) throw Exception('Order #$orderId not found');

      final orderData = orderRes.first;
      final int customerId =
          int.tryParse(orderData['customerId'].toString()) ?? 0;
      final double currentReceived =
          double.tryParse(orderData['received'].toString()) ?? 0.0;
      final double grandTotal =
          double.tryParse(orderData['grandTotal'].toString()) ?? 0.0;

      // Calculate new received amount
      final double newReceived = currentReceived + amount;

      // Update Order received
      await _dbService.execute(
          'UPDATE `order` SET received = :recv WHERE id = :id',
          {'recv': newReceived, 'id': orderId});

      // 7.2 ดึงหนี้ปัจจุบัน
      final custRes = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
        {'id': customerId},
      );
      double currentDebt = 0.0;
      if (custRes.isNotEmpty) {
        currentDebt =
            double.tryParse(custRes.first['currentDebt'].toString()) ?? 0.0;
      }
      final double balanceBefore = currentDebt;
      final double balanceAfter = currentDebt - amount;

      // 7.3 ตัดหนี้ลูกค้า
      await _dbService.execute(
        'UPDATE customer SET currentDebt = currentDebt - :amt WHERE id = :id',
        {'amt': amount, 'id': customerId},
      );

      // 7.4 ถ้าจ่ายครบแล้ว ให้ปิดบิล (เปลี่ยนสถานะเป็น COMPLETED และ paymentMethod = 'credit')
      // เพื่อให้หายจากรายการลูกหนี้ (เพราะ HELD หรือ Credit ที่ค้างจ่ายจะหายไป)
      // และการตั้งเป็น 'credit' เพื่อให้ Dashboard ไม่นับซ้ำ (Dashboard นับ DebtPayment แทน)
      if ((grandTotal - newReceived).abs() < 0.01) {
        await _dbService.execute(
            "UPDATE `order` SET status = 'COMPLETED', paymentMethod = 'credit' WHERE id = :id",
            {'id': orderId});
      }

      // 7.5 บันทึก Transaction Log (DEBT_PAYMENT)
      // เพื่อให้ไปขึ้นหน้า Dashboard
      const sqlLog = '''
        INSERT INTO debtor_transaction 
        (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
        VALUES (:cid, :oid, 'DEBT_PAYMENT', :amt, :bBefore, :bAfter, :note, NOW());
      ''';

      // ถ้าจ่ายครบ ให้ Log ว่า "ปิดบิล" ถ้าบางส่วน Log ว่า "ชำระบางส่วน"
      // Check completeness (allowing small float diffs)
      final bool isFullyPaid = (grandTotal - newReceived).abs() < 0.01;
      final String note = isFullyPaid
          ? 'ชำระปิดบิล #$orderId'
          : 'ชำระบางส่วน #$orderId (เหลือ ${(grandTotal - newReceived).toStringAsFixed(2)})';

      await _dbService.execute(sqlLog, {
        'cid': customerId,
        'oid': orderId,
        'amt': -amount, // Record as negative (debt reduction)
        'bBefore': balanceBefore,
        'bAfter': balanceAfter,
        'note': note
      });

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error paying specific bill: $e');
      return false;
    }
  }

  // 8. ดึงรายการบิลค้างชำระของลูกค้าเฉพาะราย (สำหรับสร้างใบวางบิล)
  Future<List<OutstandingBill>> getPendingBills(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // 1. Credit Sales: Calculate remaining from Transaction History directly
      // (Credit Sale Amount + Sum of Debt Payments for that Order)
      // Note: Debt Payments are stored as negative values.
      debugPrint('Fetching pending bills for Customer ID: $customerId');

      // 1. Fetch Credit Sales (from Ledger)
      const sqlCredit = '''
        SELECT 
          dt.orderId as orderId,
          dt.customerId,
          dt.amount,
          dt.createdAt,
          'CREDIT_SALE' as transactionType,
          o.grandTotal,
          o.received
        FROM debtor_transaction dt
        LEFT JOIN `order` o ON dt.orderId = o.id
        WHERE dt.customerId = :cid
          AND dt.transactionType = 'CREDIT_SALE'
        ORDER BY dt.createdAt ASC;
      ''';

      final creditResults =
          await _dbService.query(sqlCredit, {'cid': customerId});

      final List<OutstandingBill> bills = [];
      final Set<int> existingOrderIds = {};

      for (var row in creditResults) {
        final double amount = double.tryParse(row['amount'].toString()) ?? 0.0;
        final double grandTotal =
            double.tryParse(row['grandTotal'].toString()) ?? amount;
        final double received =
            double.tryParse(row['received'].toString()) ?? 0.0;
        final double remaining = grandTotal - received;

        if (remaining > 0.01) {
          int? oId = int.tryParse(row['orderId'].toString());

          final Map<String, dynamic> map = {
            'orderId': oId,
            'customerId': customerId,
            'amount': grandTotal,
            'remaining': remaining,
            'received': received,
            'createdAt': row['createdAt'],
            'status': 'CREDIT',
            'firstName': '', // Dummy
            'lastName': '', // Dummy
          };

          bills.add(OutstandingBill.fromMap(map));
          if (oId != null) existingOrderIds.add(oId);
        }
      }

      // Sort by Date
      bills.sort((a, b) {
        return a.createdAt.compareTo(b.createdAt);
      });

      return bills;
    } catch (e) {
      debugPrint('Error fetching pending bills: $e');
      return [];
    }
  }
}
