import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import '../services/mysql_service.dart';
import '../models/debtor_transaction.dart';
import '../models/customer.dart';
import '../models/outstanding_bill.dart';
import '../services/telegram_service.dart'; // ✅ Added Import
import '../services/notification_service.dart';
import 'customer_repository.dart';

class DebtorRepository {
  final MySQLService _dbService;

  DebtorRepository({MySQLService? dbService})
      : _dbService = dbService ?? MySQLService();

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // ✅ ตรรกะหลัก: จัดการหนี้ (Atomic Update)
  // ⛔ ต้องเรียกภายใน Transaction เท่านั้น (START TRANSACTION ... COMMIT)
  // ---------------------------------------------------------------------------
  Future<Decimal> transactDebt({
    required int customerId,
    required Decimal amountChange, // + for Debt, - for Payment
    required String transactionType,
    required String note,
    int? orderId,
  }) async {
    // 1. ดึงยอดหนี้ปัจจุบัน (FOR UPDATE เพื่อล็อกแถว)
    final res = await _dbService.query(
      'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
      {'id': customerId},
    );

    Decimal currentDebt = Decimal.zero;
    if (res.isNotEmpty) {
      currentDebt = Decimal.parse(res.first['currentDebt'].toString());
    }

    final Decimal balanceBefore = currentDebt;
    final Decimal balanceAfter = currentDebt + amountChange;

    // 2. อัปเดตหนี้ลูกค้า
    await _dbService.execute(
      'UPDATE customer SET currentDebt = :bal WHERE id = :id',
      {
        'bal': balanceAfter.toDouble(),
        'id': customerId
      }, // MySQL uses Double/Decimal
    );

    // 3. บันทึก Log
    const sql = '''
      INSERT INTO debtor_transaction 
      (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
      VALUES (:cid, :oid, :type, :amt, :bBefore, :bAfter, :note, NOW());
    ''';

    await _dbService.execute(sql, {
      'cid': customerId,
      'oid': orderId,
      'type': transactionType,
      'amt': amountChange.toDouble(),
      'bBefore': balanceBefore.toDouble(),
      'bAfter': balanceAfter.toDouble(),
      'note': note,
    });

    return balanceAfter;
  }

  // ✅ Helper for Telegram Notification
  Future<void> _notifyTelegram({
    required double amount,
    required String type,
    required String note,
    int? orderId,
  }) async {
    try {
      if (await TelegramService().shouldNotify(TelegramService.keyNotifyDebt)) {
        final isDebtIncrease = amount > 0;
        final title = isDebtIncrease
            ? '📝 สร้างหนี้ใหม่ (Add Debt)'
            : '💰 ชำระหนี้ (Debt Payment)';

        final msg = '$title\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '${orderId != null ? "🧾 บิล: #$orderId\n" : ""}'
            '💵 ยอดเงิน: ${amount.abs().toStringAsFixed(2)} บาท\n'
            '📝 รายละเอียด: $note\n'
            '━━━━━━━━━━━━━━━━━━';
        TelegramService().sendMessage(msg);
      }
    } catch (e) {
      debugPrint('⚠️ Telegram Notify Error: $e');
    }
  }

  // ✅ Helper for Debt Payment Notification (Line OA Case 5 & Telegram)
  Future<void> notifyDebtPayment({
    required int customerId,
    required double amountPaid,
    required Decimal newTotalDebt,
    int? orderId,
  }) async {
    try {
      final customerRepo = CustomerRepository(dbService: _dbService);
      final customer = await customerRepo.getCustomerById(customerId);
      if (customer != null) {
        await NotificationService().sendDebtPaymentNotification(
          customer: customer,
          paidAmount: amountPaid,
          newTotalDebt: newTotalDebt.toDouble(),
          orderId: orderId,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Debt Payment Notify Error: $e');
    }
  }

  // 1. บันทึกหนี้ใหม่ (ใช้ตอนจบการขายแบบ "เชื่อ")
  Future<bool> addDebt({
    required int customerId,
    required int orderId,
    required double amount,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      await transactDebt(
        customerId: customerId,
        amountChange: Decimal.parse(amount.toString()),
        transactionType: 'CREDIT_SALE',
        note: 'ขายเชื่อจากบิล #$orderId',
        orderId: orderId,
      );

      await _dbService.execute('COMMIT;');

      // ✅ Notify Telegram
      await _notifyTelegram(
        amount: amount,
        type: 'CREDIT_SALE',
        note: 'ขายเชื่อจากบิล #$orderId',
        orderId: orderId,
      );

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
    required double amount, // ยอดที่ลูกค้าจ่ายมา (Positive)
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // Pay Debt = Reduce Debt (Negative Change)
      // Safety: Take absolute of amount then negate it to ensure it reduces debt
      final Decimal payAmount = -Decimal.parse(amount.abs().toString());

      final Decimal newDebt = await transactDebt(
        customerId: customerId,
        amountChange: payAmount,
        transactionType: 'PAYMENT',
        note: 'ชำระหนี้',
      );

      await _dbService.execute('COMMIT;');

      // ✅ Notify Debt Payment (Line OA Case 5 + Telegram)
      await notifyDebtPayment(
        customerId: customerId,
        amountPaid: amount.abs(),
        newTotalDebt: newDebt,
      );

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
      if (type == 'DEBT_PAYMENT' && orderId != null && orderId > 0) {
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

  // 5. คำนวณยอดหนี้ใหม่ (Recalculate Debt from Ledger)
  // ใช้สำหรับกรณีข้อมูลไม่ตรง หรือต้องการความแม่นยำสูง
  Future<Decimal> recalculateDebt(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // 1. Sum valid transactions
    // Updated Logic: Check both isDeleted AND Order Status (Double Safety)
    final res = await _dbService.query('''
      SELECT SUM(dt.amount) as total 
      FROM debtor_transaction dt
      LEFT JOIN `order` o ON dt.orderId = o.id
      WHERE dt.customerId = :id 
        AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL)
        AND (o.status IS NULL OR o.status != 'VOID')
    ''', {'id': customerId});

    Decimal totalDebt = Decimal.zero;
    if (res.isNotEmpty && res.first['total'] != null) {
      totalDebt = Decimal.parse(res.first['total'].toString());
    }

    // 2. Update Customer Record
    await _dbService.execute(
      'UPDATE customer SET currentDebt = :debt WHERE id = :id',
      {'debt': totalDebt.toDouble(), 'id': customerId},
    );

    debugPrint('Recalculated debt for #$customerId: $totalDebt');
    return totalDebt;
  }

  // 4. ดึงประวัติลูกหนี้รายคน
  Future<List<DebtorTransaction>> getDebtorHistory(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT * FROM debtor_transaction 
        WHERE customerId = :id AND (isDeleted = 0 OR isDeleted IS NULL)
        ORDER BY createdAt DESC;
      ''';
      final results = await _dbService.query(sql, {'id': customerId});
      return results.map((r) => DebtorTransaction.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching debtor history: $e');
      return [];
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

  // 5. ดึงรายชื่อลูกหนี้ทั้งหมด (ที่มีหนี้ค้าง > 0)
  Future<List<Customer>> getActiveDebtors() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ดึงลูกค้าที่มีหนี้มากกว่า 0 (0.01 เพื่อกัน Error ทศนิยม)
      // ดึงลูกค้าที่มีหนี้ > 0 และเรียงตามความเคลื่อนไหวล่าสุด
      const sql = '''
        SELECT c.*, MAX(dt.createdAt) as latestActivity
        FROM customer c
        LEFT JOIN debtor_transaction dt ON c.id = dt.customerId
        WHERE c.currentDebt > 0.01 AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL)
        GROUP BY c.id
        ORDER BY latestActivity DESC;
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
  // ปรับปรุง: ดึงจากตาราง order โดยตรงตามคำขอ (Bills with remaining > 0)
  Future<List<OutstandingBill>> getOutstandingCreditSales() async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // Query Order Table directly
      // Logic: Bills where received < grandTotal AND status is not VOID
      const sql = '''
        SELECT 
          o.id as orderId,
          o.customerId,
          o.grandTotal as amount,
          o.received as received,
          (o.grandTotal - o.received) as remaining,
          o.createdAt,
          IFNULL(c.firstName, 'ลูกค้าทั่วไป') as firstName,
          IFNULL(c.lastName, '') as lastName,
          IFNULL(c.phone, '-') as phone,
          c.line_user_id as lineUserId,
          IFNULL(c.currentDebt, 0) as currentDebt,
          'CREDIT' as status
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE (o.grandTotal - o.received) > 0.5 
          AND o.status != 'VOID' 
          AND o.customerId > 0
        ORDER BY o.createdAt DESC;
      ''';

      final results = await _dbService.query(sql);
      debugPrint(
          'DebtorRepository: Found ${results.length} items (Source: Order Table)');

      return results.map((r) => OutstandingBill.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching outstanding orders: $e');
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
      final Decimal currentReceived =
          Decimal.parse(orderData['received'].toString());
      final Decimal grandTotal =
          Decimal.parse(orderData['grandTotal'].toString());

      final Decimal payAmount = Decimal.parse(amount.toString());

      // Calculate new received amount
      final Decimal newReceived = currentReceived + payAmount;

      // Update Order received
      await _dbService.execute(
          'UPDATE `order` SET received = :recv WHERE id = :id',
          {'recv': newReceived.toDouble(), 'id': orderId});

      // 7.2 & 7.3 & 7.5 เรียกใช้ transactDebt (รวมตัดหนี้ + Log)
      // Check completeness (allowing small float diff - handled by Decimal comparison ideally, but using tolerance for safety)
      // But Decimal is precise!
      final bool isFullyPaid =
          (grandTotal - newReceived).abs() <= Decimal.parse('0.01');

      final String note = isFullyPaid
          ? 'ชำระปิดบิล #$orderId'
          : 'ชำระบางส่วน #$orderId (เหลือ ${(grandTotal - newReceived).toStringAsFixed(2)})';

      final Decimal newDebt = await transactDebt(
        customerId: customerId,
        amountChange: -payAmount, // ลดหนี้
        transactionType: 'DEBT_PAYMENT',
        note: note,
        orderId: orderId,
      );

      // 7.4 ถ้าจ่ายครบแล้ว ให้ปิดบิล (เปลี่ยนสถานะเป็น COMPLETED และ paymentMethod = 'credit')
      if (isFullyPaid) {
        await _dbService.execute(
            "UPDATE `order` SET status = 'COMPLETED', paymentMethod = 'credit' WHERE id = :id",
            {'id': orderId});
      }

      await _dbService.execute('COMMIT;');

      // ✅ แจ้งเตือน Line OA/Telegram ว่าชำระหนี้แล้ว
      await notifyDebtPayment(
        customerId: customerId,
        amountPaid: amount, // Use original `amount` for notification
        newTotalDebt: newDebt,
        orderId: orderId,
      );

      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error paying specific bill: $e');
      return false;
    }
  }

  // 8. ดึงรายการบิลค้างชำระ (คำนวณจาก Transaction History)
  Future<List<OutstandingBill>> getPendingBills(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      debugPrint('Fetching pending bills for Customer ID: \$customerId');

      // 1. Fetch ALL Credit Sales
      const sqlCredit = '''
        SELECT 
          dt.orderId,
          dt.amount,
          dt.createdAt,
          o.grandTotal,
          o.received
        FROM debtor_transaction dt
        LEFT JOIN `order` o ON dt.orderId = o.id
        WHERE dt.customerId = :cid
          AND dt.transactionType = 'CREDIT_SALE'
          AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL)
        ORDER BY dt.createdAt ASC;
      ''';

      // 2. Fetch ALL Payments that are linked to specific orders
      const sqlPayments = '''
        SELECT orderId, amount 
        FROM debtor_transaction 
        WHERE customerId = :cid 
          AND transactionType = 'DEBT_PAYMENT'
          AND orderId IS NOT NULL
          AND (isDeleted = 0 OR isDeleted IS NULL);
      ''';

      final creditResults =
          await _dbService.query(sqlCredit, {'cid': customerId});
      final paymentResults =
          await _dbService.query(sqlPayments, {'cid': customerId});

      // Map OrderID -> Total Paid specifically for that order
      final Map<int, double> paidMap = {};
      for (var p in paymentResults) {
        final oid = int.tryParse(p['orderId'].toString());
        final amt = double.tryParse(p['amount'].toString())?.abs() ?? 0.0;
        if (oid != null) {
          paidMap[oid] = (paidMap[oid] ?? 0.0) + amt;
        }
      }

      final List<OutstandingBill> bills = [];

      for (var row in creditResults) {
        final int? oId = int.tryParse(row['orderId'].toString());
        // If no Order ID, we can't track it individually easily, skip or treat as general debt
        if (oId == null) continue;

        final double grandTotal =
            double.tryParse(row['grandTotal'].toString()) ??
                double.tryParse(row['amount'].toString()) ??
                0.0;

        // Received from Order Table (might be partial deposit)
        final double orderReceived =
            double.tryParse(row['received'].toString()) ?? 0.0;

        // Received from Debt Payments (Specific to this order)

        // Total Paid = OrderReceived + DebtPaid
        // Note: carefully avoid double counting if order.received is updated by debt payment
        // In our new logic `processBatchPayment`, we WILL update order.received.
        // So we should rely primarily on `order.received` if it's accurate.
        // Let's rely on standard `order.received` + `remaining` calculation logic.

        // Re-read: logic in `processBatchPayment` updates `order.received`.
        // So `row['received']` should be sufficient!

        final double remaining = grandTotal - orderReceived;

        if (remaining > 0.01) {
          final Map<String, dynamic> map = {
            'orderId': oId,
            'customerId': customerId,
            'amount': grandTotal,
            'remaining': remaining,
            'received': orderReceived,
            'createdAt': row['createdAt'],
            'status': 'CREDIT',
            'firstName': '', // Dummy
            'lastName': '', // Dummy
          };
          bills.add(OutstandingBill.fromMap(map));
        }
      }

      return bills;
    } catch (e) {
      debugPrint('Error fetching pending bills: \$e');
      return [];
    }
  }

  // 9. Process Batch Payment (Multiple Bills)
  Future<bool> processBatchPayment({
    required int customerId,
    required double payAmount,
    required List<int> orderIds, // Selected Orders to clear
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      double remainingToAssign = payAmount;
      final List<String> paidBillNotes = [];

      for (final orderId in orderIds) {
        if (remainingToAssign <= 0) break;

        // Get Order Details
        final orderRes = await _dbService.query(
          'SELECT grandTotal, received FROM `order` WHERE id = :id FOR UPDATE',
          {'id': orderId},
        );

        if (orderRes.isEmpty) continue;

        final double grandTotal =
            double.tryParse(orderRes.first['grandTotal'].toString()) ?? 0.0;
        final double received =
            double.tryParse(orderRes.first['received'].toString()) ?? 0.0;
        final double outstanding = grandTotal - received;

        if (outstanding <= 0.01) continue; // Already paid

        // Amount to pay for this bill
        double payForThis = 0.0;
        if (remainingToAssign >= outstanding) {
          payForThis = outstanding;
        } else {
          payForThis = remainingToAssign;
        }

        // Update Order
        final double newReceived = received + payForThis;
        await _dbService.execute(
          'UPDATE `order` SET received = :recv WHERE id = :id',
          {'recv': newReceived, 'id': orderId},
        );

        // Check if fully paid
        if ((grandTotal - newReceived).abs() <= 0.01) {
          await _dbService.execute(
              "UPDATE `order` SET status = 'COMPLETED', paymentMethod = 'credit' WHERE id = :id",
              {'id': orderId});
        }

        paidBillNotes.add('#\$orderId');
        remainingToAssign -= payForThis;
      }

      // Record ONE Transaction for the total customer debt reduction
      // Note: We don't link specific OrderID here because it covers multiple.
      // Or we could create multiple transactions?
      // Better: One transaction for Ledger cleanliness, but Note details it.

      final String note = 'ชำระหนี้ (บิล: \${paidBillNotes.join(", ")})';

      // Reduce Customer Debt
      final Decimal payDecimal = -Decimal.parse(payAmount.toString());

      final Decimal newDebt = await transactDebt(
          customerId: customerId,
          amountChange: payDecimal,
          transactionType: 'DEBT_PAYMENT',
          note: note); // orderId is null implies bulk/mixed

      await _dbService.execute('COMMIT;');

      // Notify
      await notifyDebtPayment(
        customerId: customerId,
        amountPaid: payAmount,
        newTotalDebt: newDebt,
      );

      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error batch payment: \$e');
      return false;
    }
  }
}
