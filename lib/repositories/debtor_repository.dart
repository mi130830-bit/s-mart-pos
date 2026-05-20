import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import '../services/mysql_service.dart';
import '../models/debtor_transaction.dart';
import '../models/customer.dart';
import '../models/outstanding_bill.dart';
import '../services/telegram_service.dart';
import '../services/notification_service.dart';
import 'customer_repository.dart';

part 'debtor/debtor_repository_mutations.dart';
part 'debtor/debtor_repository_queries.dart';
part 'debtor/debtor_repository_trash.dart';

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
}
