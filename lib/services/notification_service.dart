import 'package:flutter/foundation.dart';
import 'telegram_service.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../repositories/stock_repository.dart';
import '../services/mysql_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class NotificationService {
  final TelegramService _telegramService;
  final StockRepository _stockRepo;

  NotificationService({
    TelegramService? telegramService,
    StockRepository? stockRepo,
  })  : _telegramService = telegramService ?? TelegramService(),
        _stockRepo = stockRepo ?? StockRepository();

  // --- 📱 LINE OA NOTIFICATIONS ---

  Future<void> sendLineNotification({
    required int orderId,
    required Customer? customer,
    required int scenario,
    required double grandTotal,
    required double received,
    required List<OrderItem> items,
    double debtAmount = 0.0,
    double totalDebt = 0.0,
    int pointsEarned = 0,
    int totalPoints = 0,
  }) async {
    _runSafely(() async {
      // 1. ตรวจสอบว่ามี Line ID หรือไม่
      if (customer == null || customer.id == 0) {
        debugPrint('📵 [LineOA] Skip: customer is null or general');
        return;
      }

      String? lineUserId = customer.lineUserId;
      if (lineUserId == null || lineUserId.isEmpty) {
        try {
          final db = MySQLService();
          if (!db.isConnected()) await db.connect();
          final res = await db.query(
              'SELECT line_user_id FROM customer WHERE id = :cid',
              {'cid': customer.id});
          if (res.isNotEmpty && res.first['line_user_id'] != null) {
            lineUserId = res.first['line_user_id']?.toString();
          }
        } catch (e) {
          debugPrint('⚠️ Fetch DB Line ID Error: $e');
        }
      }

      if (lineUserId == null || lineUserId.isEmpty) {
        debugPrint(
            '📵 [LineOA] Skip: customer "${customer.name}" has no lineUserId');
        return;
      }
      debugPrint(
          '📤 [LineOA] Scenario=$scenario, Order=#$orderId, LineUID=$lineUserId');

      // 2. ดึง baseUrl ของ API
      final urlStr = SettingsService().apiUrl;
      final url = Uri.parse('$urlStr/line/push-scenario');
      debugPrint('📤 [LineOA] POST → $url');

      try {
        // ✅ Count front store items (not warehouse items)
        int frontStoreCount = 0;
        for (var item in items) {
          final isWarehouse = item.product?.isWarehouseItem ?? false;
          if (!isWarehouse) {
            frontStoreCount += item.quantity.toDouble().toInt();
          }
        }

        final payload = {
          'lineUserId': lineUserId,
          'orderId': orderId.toString(),
          'scenario': scenario,
          'customerName': customer.name,
          'grandTotal': grandTotal,
          'received': received,
          'debtAmount': debtAmount,
          'totalDebt': totalDebt,
          'pointsEarned': pointsEarned,
          'totalPoints': totalPoints,
          'frontStoreItemsCount': frontStoreCount, // ✅ Added Front Store Count
          'items': items
              .map((e) => {
                    'productName': e.productName,
                    'quantity': e.quantity.toDouble(),
                    'price': e.price.toDouble(),
                  })
              .toList(),
        };

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          debugPrint(
              '❌ [LineOA] HTTP ${response.statusCode}: ${response.body}');
        } else {
          debugPrint('✅ [LineOA] Scenario $scenario ส่งสำเร็จ บิล #$orderId');
        }
      } catch (e) {
        debugPrint('❌ [LineOA] Exception: $e');
      }
    });
  }

  // --- 📱 TELEGRAM NOTIFICATIONS ---

  Future<void> sendSaleNotification({
    required int orderId,
    required double grandTotal,
    required double received,
    required String paymentMethodStr,
    required Customer? customer,
    required List<OrderItem> items,
    bool isDelivery = false, // ✅ Scenario 1 (cash) หรือ 2 (cash+delivery)
    int pointsEarned = 0,
    int totalPoints = 0,
  }) async {
    _runSafely(() async {
      // 1. ส่ง Line OA ถ้าลูกค้ามี Line ID
      final int lineScenario = isDelivery ? 2 : 1;
      await sendLineNotification(
        orderId: orderId,
        customer: customer,
        scenario: lineScenario,
        grandTotal: grandTotal,
        received: received,
        items: items,
        pointsEarned: pointsEarned,
        totalPoints: totalPoints,
      );

      // 2. ส่ง Telegram (ถ้าเปิดใช้งาน)
      if (!await _telegramService.shouldNotify('telegram_notify_payment')) {
        return;
      }

      String msg = '💰 *แจ้งเตือนการขาย* (New Sale)\n'
          '━━━━━━━━━━━━━━━━━━\n'
          '🧾 *เลขที่บิล:* #$orderId\n'
          '👤 *ลูกค้า:* ${customer?.name ?? "ทั่วไป"}\n'
          '📦 *รายการสินค้า:* ${items.length} รายการ\n';

      for (var item in items) {
        msg += '- ${item.productName} x ${item.quantity.toStringAsFixed(0)}\n';
      }

      final double change =
          (received > grandTotal) ? (received - grandTotal) : 0.0;

      msg += '━━━━━━━━━━━━━━━━━━\n'
          '💵 *ยอดสุทธิ:* ${grandTotal.toStringAsFixed(2)} บาท\n'
          '📥 *รับเงิน:* ${received.toStringAsFixed(2)} บาท\n'
          '💸 *เงินทอน:* ${change.toStringAsFixed(2)} บาท\n'
          '🏷️ *วิธีชำระ:* $paymentMethodStr\n'
          '━━━━━━━━━━━━━━━━━━';

      await _telegramService.sendMessage(msg);
    });
  }

  // ✅ Combined Notification for Credit Sales (Telegram + Line OA)
  Future<void> sendCreditSaleNotification({
    required int orderId,
    required double grandTotal,
    required double received,
    required List<OrderItem> items,
    required Customer customer,
    required double debtAmount,
    required double totalDebt,
    bool isDelivery = false, // ✅ Scenario 3 (credit) หรือ 4 (credit+delivery)
    int pointsEarned = 0,
    int totalPoints = 0,
  }) async {
    _runSafely(() async {
      // 1. ส่ง Line OA ถ้าลูกค้ามี Line ID
      final int lineScenario = isDelivery ? 4 : 3;
      await sendLineNotification(
        orderId: orderId,
        customer: customer,
        scenario: lineScenario,
        grandTotal: grandTotal,
        received: received,
        items: items,
        debtAmount: debtAmount,
        totalDebt: totalDebt,
        pointsEarned: pointsEarned,
        totalPoints: totalPoints,
      );

      // 2. ส่ง Telegram (ถ้าเปิดใช้งาน)
      if (!await _telegramService.shouldNotify('telegram_notify_debt')) {
        return;
      }

      String msg = '💰 *ขายเงินเชื่อ/ลงบิล* (Credit Sale)\n'
          '━━━━━━━━━━━━━━━━━━\n'
          '🧾 *เลขที่บิล:* #$orderId\n'
          '👤 *ลูกค้า:* ${customer.name}\n'
          '📦 *รายการสินค้า:* ${items.length} รายการ\n';

      for (var item in items) {
        msg += '- ${item.productName} x ${item.quantity.toStringAsFixed(0)}\n';
      }

      msg += '━━━━━━━━━━━━━━━━━━\n'
          '💵 *ยอดบิลนี้:* ${grandTotal.toStringAsFixed(2)} บาท\n'
          '💳 *ชำระล่วงหน้า:* ${received.toStringAsFixed(2)} บาท\n'
          '📉 *ค้างชำระเพิ่ม:* ${debtAmount.toStringAsFixed(2)} บาท\n'
          '📊 *หนี้รวม:* ${totalDebt.toStringAsFixed(2)} บาท\n'
          '━━━━━━━━━━━━━━━━━━';

      await _telegramService.sendMessage(msg);
    });
  }

  // Legacy Debt Notification (Keep for manual debt recording not via sale if any)
  Future<bool> sendDebtNotification({
    required int orderId,
    required double debtAmount,
    required double totalDebt,
    required Customer customer,
  }) async {
    try {
      if (!await _telegramService.shouldNotify('telegram_notify_debt')) {
        return false;
      }

      await _telegramService
          .sendMessage('📝 *บันทึกหนี้ร้านค้า* (Debt Recorded)\n'
              '🧾 *เลขที่บิล:* #$orderId\n'
              '👤 *ลูกค้า:* ${customer.name}\n'
              '💰 *ยอดหนี้เพิ่ม:* ${debtAmount.toStringAsFixed(2)} บาท\n'
              '📊 *หนี้รวม:* ${totalDebt.toStringAsFixed(2)} บาท\n'
              '━━━━━━━━━━━━━━━━━━');
      return true;
    } catch (e) {
      debugPrint('Error sending debt notify: $e');
      return false;
    }
  }

  // ✅ New Debt Payment Notification (Scenario 5)
  Future<void> sendDebtPaymentNotification({
    required Customer customer,
    required double paidAmount,
    required double newTotalDebt,
    int? orderId,
  }) async {
    _runSafely(() async {
      // 1. ส่ง Line OA
      await sendLineNotification(
        orderId: orderId ?? 0,
        customer: customer,
        scenario: 5,
        grandTotal: 0.0,
        received: paidAmount,
        items: [],
        totalDebt: newTotalDebt,
      );

      // 2. ส่ง Telegram
      if (!await _telegramService.shouldNotify('telegram_notify_debt')) {
        return;
      }

      String msg = '💰 *ชำระหนี้* (Debt Payment)\n'
          '━━━━━━━━━━━━━━━━━━\n'
          '${orderId != null && orderId > 0 ? "🧾 *อ้างอิงบิล:* #$orderId\n" : ""}'
          '👤 *ลูกค้า:* ${customer.name}\n'
          '💵 *ยอดชำระ:* ${paidAmount.toStringAsFixed(2)} บาท\n'
          '📊 *หนี้รวมคงเหลือ:* ${newTotalDebt.toStringAsFixed(2)} บาท\n'
          '━━━━━━━━━━━━━━━━━━';

      await _telegramService.sendMessage(msg);
    });
  }

  Future<void> sendLowStockAlert(
      OrderItem item, double currentStock, double reorderPoint) async {
    _runSafely(() async {
      if (!await _telegramService.shouldNotify('telegram_notify_low_stock')) {
        return;
      }

      String extraInfo = '';
      final lastPurchase = await _stockRepo.getLastPurchase(item.productId);
      if (lastPurchase != null) {
        final cost = lastPurchase['price'] ?? '-';
        extraInfo += '💰 ต้นทุนล่าสุด: $cost\n';
      }

      await _telegramService
          .sendMessage('⚠️ *แจ้งเตือนสินค้าใกล้หมด* (Low Stock Alert)\n'
              '📦 *สินค้า:* ${item.productName}\n'
              '📉 *คงเหลือ:* $currentStock (จุดสั่งซื้อ: $reorderPoint)\n'
              '$extraInfo'
              '━━━━━━━━━━━━━━━━━━');
    });
  }

  Future<void> sendBackupFailedNotification(String error) async {
    _runSafely(() async {
      if (!await _telegramService
          .shouldNotify(TelegramService.keyNotifyBackup)) {
        return;
      }

      await _telegramService
          .sendMessage('🚨 *แจ้งเตือนสำรองข้อมูลล้มเหลว* (Backup Failed)\n'
              '━━━━━━━━━━━━━━━━━━\n'
              '❌ *สาเหตุ:* $error\n'
              '⚠️ *คำแนะนำ:* โปรดตรวจสอบการเชื่อมต่อ Google Drive ใหม่\n'
              '━━━━━━━━━━━━━━━━━━');
    });
  }

  // Wrapper to run async without blocking but prevent unhandled exceptions crashing app (though futures usually don't crash main isolate unless awaited)
  void _runSafely(Future<void> Function() action) {
    action().catchError((e) {
      debugPrint('Notification Service Error: $e');
    });
  }
}
