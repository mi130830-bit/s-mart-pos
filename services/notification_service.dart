import 'package:flutter/foundation.dart';
import 'telegram_service.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../repositories/stock_repository.dart';

class NotificationService {
  final TelegramService _telegramService;
  final StockRepository _stockRepo;

  NotificationService({
    TelegramService? telegramService,
    StockRepository? stockRepo,
  })  : _telegramService = telegramService ?? TelegramService(),
        _stockRepo = stockRepo ?? StockRepository();

  Future<void> sendSaleNotification({
    required int orderId,
    required double grandTotal,
    required double received,
    required String paymentMethodStr,
    required Customer? customer,
  }) async {
    // Fire and forget (don't await result to block UI, but catch errors)
    _runSafely(() async {
      if (!await _telegramService.shouldNotify('telegram_notify_payment')) {
        return;
      }

      String msg = '💰 *แจ้งเตือนการขาย* (New Sale)\n'
          '━━━━━━━━━━━━━━━━━━\n'
          '🧾 *เลขที่บิล:* #$orderId\n'
          '💵 *ยอดสุทธิ:* ${grandTotal.toStringAsFixed(2)} บาท\n'
          '📥 *รับเงิน:* ${received.toStringAsFixed(2)} บาท\n'
          '🏷️ *วิธีชำระ:* $paymentMethodStr\n';
      if (customer != null) {
        msg += '👤 *ลูกค้า:* ${customer.name}\n';
      }
      msg += '━━━━━━━━━━━━━━━━━━';
      await _telegramService.sendMessage(msg);
    });
  }

  Future<bool> sendDebtNotification({
    required int orderId,
    required double debtAmount,
    required double totalDebt,
    required Customer customer,
  }) async {
    // Returns true if sent, so we can know not to send duplicate sale notify if needed logic requires it.
    // However, usually we can just fire both or handle logic in caller.
    // Caller `OrderProcessingService` uses return value `sentDebtNotify`.
    // So I will make this return Future<bool>.

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

  // Wrapper to run async without blocking but prevent unhandled exceptions crashing app (though futures usually don't crash main isolate unless awaited)
  void _runSafely(Future<void> Function() action) {
    action().catchError((e) {
      debugPrint('Notification Service Error: $e');
    });
  }
}
