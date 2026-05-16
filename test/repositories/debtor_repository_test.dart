// ignore_for_file: lines_longer_than_80_chars
// ============================================================
// Unit Tests: DebtorRepository — Debt Calculation Logic
//
// เป้าหมาย: ตรวจสอบว่า Logic การคำนวณยอดหนี้ถูกต้อง 100%
// โดยใช้ StatefulMockMySQLService ที่ควบคุม Response ได้
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import 'package:pos_desktop/repositories/debtor_repository.dart';
import 'package:pos_desktop/services/mysql_service.dart';

// ---------------------------------------------------------------------------
// Stateful Mock — จำค่าที่ถูก execute/query ล่าสุดเอาไว้
// ---------------------------------------------------------------------------

class _MockResultSet implements IResultSet {
  @override
  BigInt get lastInsertID => BigInt.from(1);

  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}

/// Mock ที่ "ฉลาด": ส่ง Response ตามชนิดของ SQL ที่ถาม
/// และบันทึก params ทุกตัวไว้ให้ test ตรวจสอบ
class StatefulMockDB implements MySQLService {
  // --- State ที่ test กำหนด ---
  /// ยอดหนี้ปัจจุบันของลูกค้า (mock currentDebt ใน DB)
  double customerDebt;

  /// ข้อมูล debtor_transaction ที่จะตอบกลับ (สำหรับ deleteTransaction / restoreTransaction)
  Map<String, dynamic>? transactionRow;

  /// ข้อมูล order ที่จะตอบกลับ (สำหรับ paySpecificBill / processBatchPayment)
  Map<String, dynamic>? orderRow;

  StatefulMockDB({
    this.customerDebt = 0.0,
    this.transactionRow,
    this.orderRow,
  });

  // --- สิ่งที่ test จะตรวจสอบ ---
  final List<String> executedSqls = [];
  final List<Map<String, dynamic>> executedParams = [];

  void _record(String sql, Map<String, dynamic>? params) {
    executedSqls.add(sql);
    executedParams.add(params ?? {});
  }

  @override
  Future<void> connect() async {}

  @override
  bool isConnected() => true;

  @override
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    _record(sql, params);
    return _MockResultSet();
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    _record(sql, params);

    // --- ตอบ currentDebt สำหรับ customer query ---
    if (sql.contains('SELECT currentDebt FROM customer')) {
      return [
        {'currentDebt': customerDebt},
      ];
    }

    // --- ตอบ debtor_transaction (สำหรับ deleteTransaction / restoreTransaction) ---
    if (sql.contains('FROM debtor_transaction WHERE id')) {
      return transactionRow != null ? [transactionRow!] : [];
    }

    // --- ตอบ order (สำหรับ paySpecificBill / processBatchPayment) ---
    if (sql.contains("FROM `order` WHERE id")) {
      return orderRow != null ? [orderRow!] : [];
    }

    // ORDER details สำหรับ processBatchPayment loop
    if (sql.contains('SELECT grandTotal, received')) {
      return orderRow != null ? [orderRow!] : [];
    }

    return [];
  }

  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // เริ่ม Flutter binding ก่อน เพื่อป้องกัน Warning จาก TelegramService
  // ที่ใช้ SharedPreferences (ต้องการ ServicesBinding) ใน _notifyTelegram()
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // GROUP 1: transactDebt — Core Balance Calculation
  // =========================================================================
  group('transactDebt — Core Balance Calculation', () {
    test('1. คำนวณ balanceAfter = balanceBefore + amountChange ถูกต้อง',
        () async {
      // Arrange: ลูกค้ามีหนี้ 500 บาท, เพิ่มหนี้ 200 บาท
      final db = StatefulMockDB(customerDebt: 500.0);
      final repo = DebtorRepository(dbService: db);

      // Act
      final result = await repo.transactDebt(
        customerId: 1,
        amountChange: Decimal.parse('200.00'),
        transactionType: 'CREDIT_SALE',
        note: 'ขายเชื่อ',
      );

      // Assert: balanceAfter ต้องเท่ากับ 700
      expect(result, equals(Decimal.parse('700.00')),
          reason: 'balanceAfter = 500 + 200 = 700');
    });

    test('2. transactDebt ส่งค่า balanceAfter ที่ถูกต้องใน UPDATE customer',
        () async {
      // Arrange: หนี้เดิม 1000, ชำระ 300
      final db = StatefulMockDB(customerDebt: 1000.0);
      final repo = DebtorRepository(dbService: db);

      await repo.transactDebt(
        customerId: 5,
        amountChange: Decimal.parse('-300.00'),
        transactionType: 'PAYMENT',
        note: 'ชำระหนี้',
      );

      // หา UPDATE customer ใน executedParams
      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      expect(updateIdx, greaterThan(-1), reason: 'ต้องมีการ UPDATE customer');

      final updateParams = db.executedParams[updateIdx];
      // balanceAfter = 1000 - 300 = 700
      expect(updateParams['bal'], closeTo(700.0, 0.001),
          reason: 'UPDATE ต้องใช้ค่า 700 (1000 - 300)');
      expect(updateParams['id'], equals(5));
    });

    test('3. transactDebt บันทึก balanceBefore และ balanceAfter ใน Log ถูกต้อง',
        () async {
      // Arrange: หนี้เดิม 250
      final db = StatefulMockDB(customerDebt: 250.0);
      final repo = DebtorRepository(dbService: db);

      await repo.transactDebt(
        customerId: 2,
        amountChange: Decimal.parse('150.00'),
        transactionType: 'CREDIT_SALE',
        note: 'Test',
        orderId: 99,
      );

      // หา INSERT INTO debtor_transaction
      final insertIdx = db.executedSqls
          .indexWhere((s) => s.contains('INSERT INTO debtor_transaction'));
      expect(insertIdx, greaterThan(-1), reason: 'ต้องมี INSERT log');

      final logParams = db.executedParams[insertIdx];
      expect(logParams['bBefore'], closeTo(250.0, 0.001),
          reason: 'balanceBefore ต้องเป็น 250');
      expect(logParams['bAfter'], closeTo(400.0, 0.001),
          reason: 'balanceAfter ต้องเป็น 400 (250 + 150)');
      expect(logParams['oid'], equals(99));
      expect(logParams['type'], equals('CREDIT_SALE'));
    });

    test('4. หนี้เริ่มต้น 0 — transactDebt คำนวณถูกต้อง', () async {
      final db = StatefulMockDB(customerDebt: 0.0);
      final repo = DebtorRepository(dbService: db);

      final result = await repo.transactDebt(
        customerId: 3,
        amountChange: Decimal.parse('999.99'),
        transactionType: 'CREDIT_SALE',
        note: 'ลูกค้าใหม่',
      );

      expect(result, equals(Decimal.parse('999.99')));
    });
  });

  // =========================================================================
  // GROUP 2: addDebt — ส่งค่าบวก (เพิ่มหนี้)
  // =========================================================================
  group('addDebt — เพิ่มหนี้ลูกค้า', () {
    test('5. addDebt ส่ง amountChange เป็นค่าบวกเสมอ', () async {
      final db = StatefulMockDB(customerDebt: 0.0);
      final repo = DebtorRepository(dbService: db);

      await repo.addDebt(customerId: 1, orderId: 10, amount: 500.0);

      // ตรวจสอบ UPDATE customer
      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      expect(updateIdx, greaterThan(-1));

      final bal = db.executedParams[updateIdx]['bal'] as double;
      expect(bal, greaterThan(0), reason: 'addDebt ต้องเพิ่มหนี้ (ค่าบวก)');
      expect(bal, closeTo(500.0, 0.001));
    });

    test('6. addDebt บันทึก transactionType = CREDIT_SALE', () async {
      final db = StatefulMockDB(customerDebt: 0.0);
      final repo = DebtorRepository(dbService: db);

      final success =
          await repo.addDebt(customerId: 10, orderId: 20, amount: 300.0);

      expect(success, isTrue);

      final insertIdx = db.executedSqls
          .indexWhere((s) => s.contains('INSERT INTO debtor_transaction'));
      expect(insertIdx, greaterThan(-1));
      expect(db.executedParams[insertIdx]['type'], equals('CREDIT_SALE'));
    });
  });

  // =========================================================================
  // GROUP 3: payDebt — ส่งค่าลบ (ลดหนี้)
  // =========================================================================
  group('payDebt — ชำระหนี้ลูกค้า', () {
    test('7. payDebt ส่ง amountChange เป็นค่าลบ (ลดหนี้)', () async {
      final db = StatefulMockDB(customerDebt: 800.0);
      final repo = DebtorRepository(dbService: db);

      await repo.payDebt(customerId: 1, amount: 300.0);

      // UPDATE customer: balanceAfter = 800 - 300 = 500
      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      expect(updateIdx, greaterThan(-1));

      final bal = db.executedParams[updateIdx]['bal'] as double;
      expect(bal, closeTo(500.0, 0.001),
          reason: 'หนี้หลังชำระ = 800 - 300 = 500');
    });

    test(
        '8. payDebt: ถ้าส่ง amount ติดลบมา ก็ต้องยัง "ลดหนี้" ได้ (safety negate)',
        () async {
      // เหตุผล: payDebt ใช้ amount.abs() ป้องกัน sign ผิด
      final db = StatefulMockDB(customerDebt: 1000.0);
      final repo = DebtorRepository(dbService: db);

      // ส่ง -200 แต่ logic ต้อง negate เป็น -200 อยู่ดี (ลดหนี้ 200)
      await repo.payDebt(customerId: 1, amount: -200.0);

      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      final bal = db.executedParams[updateIdx]['bal'] as double;

      // ไม่ว่า amount จะ positive หรือ negative ต้องลดหนี้ 200
      expect(bal, closeTo(800.0, 0.001),
          reason: 'ไม่ว่า input จะเป็น +200 หรือ -200 → หนี้ต้องลดลง 200');
    });
  });

  // =========================================================================
  // GROUP 4: deleteTransaction — Soft Delete & Revert Balance
  // =========================================================================
  group('deleteTransaction — ลบรายการและย้อน Balance', () {
    test('9. ลบ CREDIT_SALE (+500) → หนี้ลดลง: newDebt = 800 - 500 = 300',
        () async {
      // Arrange:  หนี้ปัจจุบัน 800, กำลังลบ transaction ที่มี amount = +500 (เชื่อ)
      final db = StatefulMockDB(
        customerDebt: 800.0,
        transactionRow: {
          'id': 1,
          'customerId': '7',
          'amount': '500.0',
          'transactionType': 'CREDIT_SALE',
        },
      );
      final repo = DebtorRepository(dbService: db);

      final success = await repo.deleteTransaction(1);
      expect(success, isTrue);

      // หา UPDATE customer
      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      expect(updateIdx, greaterThan(-1));
      // newDebt = currentDebt - amount = 800 - 500 = 300
      expect(db.executedParams[updateIdx]['bal'], closeTo(300.0, 0.001),
          reason: 'ลบ credit sale → หนี้ลดลง');
    });

    test('10. ลบ PAYMENT (-300) → หนี้เพิ่มขึ้น: newDebt = 500 - (-300) = 800',
        () async {
      // ถ้าลบรายการ "จ่ายหนี้" → หนี้ต้องเพิ่มกลับมา
      final db = StatefulMockDB(
        customerDebt: 500.0,
        transactionRow: {
          'id': 2,
          'customerId': '7',
          'amount': '-300.0', // payment ถูกเก็บเป็นค่าลบ
          'transactionType': 'PAYMENT',
        },
      );
      final repo = DebtorRepository(dbService: db);

      await repo.deleteTransaction(2);

      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      // newDebt = 500 - (-300) = 800
      expect(db.executedParams[updateIdx]['bal'], closeTo(800.0, 0.001),
          reason: 'ลบ payment → หนี้เพิ่มกลับ');
    });

    test('11. deleteTransaction ทำ Soft Delete (isDeleted = 1) ไม่ใช่ลบจริง',
        () async {
      final db = StatefulMockDB(
        customerDebt: 200.0,
        transactionRow: {
          'id': 5,
          'customerId': '3',
          'amount': '100.0',
          'transactionType': 'CREDIT_SALE',
        },
      );
      final repo = DebtorRepository(dbService: db);

      await repo.deleteTransaction(5);

      final hasSoftDelete =
          db.executedSqls.any((s) => s.contains('isDeleted = 1'));
      expect(hasSoftDelete, isTrue,
          reason: 'ต้อง Soft Delete (isDeleted = 1) ไม่ใช่ DELETE จริง');

      final hasHardDelete =
          db.executedSqls.any((s) => s.contains('DELETE FROM'));
      expect(hasHardDelete, isFalse, reason: 'ห้าม DELETE ตรงๆ');
    });
  });

  // =========================================================================
  // GROUP 5: restoreTransaction — กู้คืนและ Re-Apply Balance
  // =========================================================================
  group('restoreTransaction — กู้คืนรายการ', () {
    test(
        '12. กู้คืน CREDIT_SALE (+500) → หนี้เพิ่มขึ้น: newDebt = 300 + 500 = 800',
        () async {
      // ตรงข้ามกับ deleteTransaction
      final db = StatefulMockDB(
        customerDebt: 300.0,
        transactionRow: {
          'id': 3,
          'customerId': '8',
          'amount': '500.0',
        },
      );
      final repo = DebtorRepository(dbService: db);

      final success = await repo.restoreTransaction(3);
      expect(success, isTrue);

      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      // newDebt = currentDebt + amount = 300 + 500 = 800
      expect(db.executedParams[updateIdx]['bal'], closeTo(800.0, 0.001),
          reason: 'restoreTransaction ต้อง re-apply หนี้กลับมา');
    });

    test('13. กู้คืน PAYMENT (-300) → หนี้ลดลง: newDebt = 800 + (-300) = 500',
        () async {
      final db = StatefulMockDB(
        customerDebt: 800.0,
        transactionRow: {
          'id': 4,
          'customerId': '8',
          'amount': '-300.0',
        },
      );
      final repo = DebtorRepository(dbService: db);

      await repo.restoreTransaction(4);

      final updateIdx = db.executedSqls
          .indexWhere((s) => s.contains('UPDATE customer SET currentDebt'));
      // newDebt = 800 + (-300) = 500
      expect(db.executedParams[updateIdx]['bal'], closeTo(500.0, 0.001),
          reason: 'restore payment → หนี้ลดลง (re-apply การชำระ)');
    });
  });

  // =========================================================================
  // GROUP 6: processBatchPayment — จ่ายหลายบิล
  // =========================================================================
  group('processBatchPayment — ชำระหนี้หลายบิล', () {
    test('14. จ่าย 1 บิลครบ → UPDATE order received = grandTotal และปิดบิล',
        () async {
      // Order 10: grandTotal 500, received 0 → ยอดค้าง 500
      // จ่าย 500 → ปิดบิลครบ
      final db = StatefulMockDB(
        customerDebt: 500.0,
        orderRow: {'grandTotal': '500.0', 'received': '0.0'},
      );
      final repo = DebtorRepository(dbService: db);

      final success = await repo.processBatchPayment(
        customerId: 1,
        payAmount: 500.0,
        orderIds: [10],
      );

      expect(success, isTrue);

      // ตรวจว่า UPDATE order received ถูกเรียก
      final updateOrder =
          db.executedSqls.any((s) => s.contains("UPDATE `order` SET received"));
      expect(updateOrder, isTrue, reason: 'ต้องอัปเดต order.received');

      // ตรวจว่าปิดบิล (COMPLETED)
      final closedBill =
          db.executedSqls.any((s) => s.contains("status = 'COMPLETED'"));
      expect(closedBill, isTrue, reason: 'จ่ายครบต้องปิดบิล COMPLETED');
    });

    test('15. จ่ายบางส่วน → ยอดที่ assign ลดลง แต่ไม่ปิดบิล', () async {
      // Order 20: grandTotal 1000, received 0 → ยอดค้าง 1000
      // จ่ายแค่ 400 → เหลือ 600
      final db = StatefulMockDB(
        customerDebt: 1000.0,
        orderRow: {'grandTotal': '1000.0', 'received': '0.0'},
      );
      final repo = DebtorRepository(dbService: db);

      final success = await repo.processBatchPayment(
        customerId: 2,
        payAmount: 400.0,
        orderIds: [20],
      );

      expect(success, isTrue);

      // ต้องไม่ปิดบิล
      final closedBill =
          db.executedSqls.any((s) => s.contains("status = 'COMPLETED'"));
      expect(closedBill, isFalse, reason: 'จ่ายบางส่วน ห้ามปิดบิล COMPLETED');
    });

    test('16. บิลที่ชำระครบแล้ว (outstanding <= 0.01) ต้องถูกข้าม', () async {
      // Order: grandTotal 500, received 500 → ไม่มีค้าง
      final db = StatefulMockDB(
        customerDebt: 0.0,
        orderRow: {'grandTotal': '500.0', 'received': '500.0'},
      );
      final repo = DebtorRepository(dbService: db);

      await repo.processBatchPayment(
        customerId: 3,
        payAmount: 200.0,
        orderIds: [30],
      );

      // ไม่ควรมีการ UPDATE order (เพราะข้ามบิลที่จ่ายแล้ว)
      final updatedOrder = db.executedSqls
          .where((s) => s.contains("UPDATE `order` SET received"))
          .toList();
      expect(updatedOrder.isEmpty, isTrue,
          reason: 'บิลที่จ่ายแล้วต้องถูกข้าม ไม่ควร UPDATE');
    });

    test('17. transactDebt ถูกเรียกครั้งเดียวสำหรับยอดรวมทั้งหมด', () async {
      // ตรวจว่า processBatchPayment เรียก transactDebt 1 ครั้ง
      // (ไม่ใช่ทีละบิล) ตามหลักการ Ledger Cleanliness
      final db = StatefulMockDB(
        customerDebt: 1000.0,
        orderRow: {'grandTotal': '300.0', 'received': '0.0'},
      );
      final repo = DebtorRepository(dbService: db);

      await repo.processBatchPayment(
        customerId: 4,
        payAmount: 300.0,
        orderIds: [41],
      );

      // ต้องมี INSERT INTO debtor_transaction เพียง 1 ครั้ง
      final insertCount = db.executedSqls
          .where((s) => s.contains('INSERT INTO debtor_transaction'))
          .length;
      expect(insertCount, equals(1),
          reason: 'บันทึก debt transaction 1 รายการต่อการชำระทั้งหมด');
    });
  });
}
