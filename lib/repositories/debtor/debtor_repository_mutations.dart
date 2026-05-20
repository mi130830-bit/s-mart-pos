part of '../debtor_repository.dart';

extension DebtorRepositoryMutations on DebtorRepository {
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

        // ✅ สร้าง Transaction แยกลงแต่ละบิล (เพื่อให้สามารถกดยกเลิก/Revert การจ่ายเงินรายบิลได้)
        final String note = 'ชำระหนี้บิล #$orderId';
        final Decimal payDecimal = -Decimal.parse(payForThis.toString());

        await transactDebt(
            customerId: customerId,
            amountChange: payDecimal,
            transactionType: 'DEBT_PAYMENT',
            orderId: orderId, // ผูกกับบิลนี้
            note: note);

        paidBillNotes.add('#$orderId');
        remainingToAssign -= payForThis;
      }

      // ถ้าเงินเหลือแต่ไม่มีบิลให้ตัดแล้ว (จ่ายเกิน) ค่อยทำ Transaction เปล่า (เก็บเครดิต)
      if (remainingToAssign > 0.01) {
        final Decimal payDecimal = -Decimal.parse(remainingToAssign.toString());
        await transactDebt(
            customerId: customerId,
            amountChange: payDecimal,
            transactionType: 'DEBT_PAYMENT',
            note: 'ชำระหนี้ (ไม่ระบุบิล/ชำระเกิน)');
      }

      await _dbService.execute('COMMIT;');

      // Notify ยอดรวม
      // คำนวณหนี้คงเหลือหลังสุด เพื่อส่งให้แจ้งเตือน
      final custRes = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id',
        {'id': customerId},
      );
      Decimal currentDebt = Decimal.zero;
      if (custRes.isNotEmpty) {
        currentDebt = Decimal.parse(custRes.first['currentDebt'].toString());
      }

      // Notify
      await notifyDebtPayment(
        customerId: customerId,
        amountPaid: payAmount,
        newTotalDebt: currentDebt,
      );

      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error batch payment: $e');
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
}
