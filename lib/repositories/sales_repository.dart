import '../services/logger_service.dart';
import '../services/mysql_service.dart';
import '../services/telegram_service.dart';
import '../services/settings_service.dart';
// import '../services/api_service.dart';
import '../models/order_item.dart';
import '../services/ai_office_service.dart'; // [Added] AI Office Webhook
import './activity_repository.dart';
import './debtor_repository.dart'; // Added
import './stock_repository.dart'; // ✅ Added for composite stock deduction
import 'package:decimal/decimal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schema/order_collection.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';

part 'sales/sales_command_extension.dart';
part 'sales/sales_query_extension.dart';
part 'sales/sales_analytics_extension.dart';
part 'sales/sales_return_extension.dart';
part 'sales/sales_edit_order_extension.dart'; // ✅ [NEW] แก้ไขบิล UNPAID

class SalesRepository {
  final MySQLService _dbService;
  final ActivityRepository _activityRepo;
  final DebtorRepository _debtorRepo;

  SalesRepository({
    MySQLService? dbService,
    ActivityRepository? activityRepo,
    DebtorRepository? debtorRepo,
  })  : _dbService = dbService ?? MySQLService(),
        _activityRepo = activityRepo ?? ActivityRepository(),
        _debtorRepo = debtorRepo ?? DebtorRepository();


  // --- Helpers ---
  // --- 9. Helpers ---
  Future<void> _triggerLineReceipt(
      int orderId, int customerId, double amount) async {
    try {
      // 1. Get Customer Line ID & Points from Local DB
      if (!_dbService.isConnected()) await _dbService.connect();
      final res = await _dbService.query(
        'SELECT line_user_id, currentPoints FROM customer WHERE id = :id',
        {'id': customerId},
      );

      if (res.isNotEmpty) {
        final lineUserId = res.first['line_user_id'];
        final currentPoints = res.first['currentPoints'];

        if (lineUserId != null && lineUserId.toString().isNotEmpty) {
          // 2. Call Backend API (Fire & Forget)
          final url =
              Uri.parse('http://127.0.0.1:8080/api/v1/line/push-receipt');
          http
              .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lineUserId': lineUserId.toString(),
              'orderId': orderId.toString(),
              'amount': amount,
              'points': currentPoints ?? 0,
            }),
          )
              .timeout(const Duration(seconds: 5), onTimeout: () {
            return http.Response('Timeout', 408);
          }).then((response) {
            if (response.statusCode != 200) {
              LoggerService.warning('SalesRepository', 'Line Receipt Push Failed: ${response.body}');
            } else {
              LoggerService.info('SalesRepository', 'Line Receipt Triggered for Order #$orderId');
            }
          }).catchError((e) {
            LoggerService.error('SalesRepository', 'Line Receipt Connection Error', e);
          });
        }
      }
    } catch (e) {
      LoggerService.error('SalesRepository', 'Line Receipt Logic Error', e);
    }
  }

  // ✅ Helper for Telegram Notification
  Future<void> _notifyTelegram(
      int orderId, double amount, String method, List<OrderItem> items) async {
    LoggerService.info('SalesRepository', 'Triggering Telegram Notify for Order #$orderId...');
    try {
      if (await TelegramService()
          .shouldNotify(TelegramService.keyNotifyPayment)) {
        final time = DateTime.now().toString().substring(11, 16); // HH:mm

        // Format Items List
        String itemsList = '';
        for (var item in items) {
          itemsList += '- ${item.productName} x ${item.quantity}\n';
        }
        if (itemsList.length > 500) {
          itemsList = '${itemsList.substring(0, 500)}... (มีต่อ)';
        }

        final msg = '💰 *แจ้งเตือนการขาย* (New Sale)\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '🧾 *บิล:* #$orderId\n'
            '⏰ *เวลา:* $time\n'
            '💵 *ยอดเงิน:* ${amount.toStringAsFixed(2)} บาท\n'
            '📥 *รับเงิน:* ${amount.toStringAsFixed(2)} บาท\n'
            '💸 *เงินทอน:* 0.00 บาท\n'
            '💳 *ชำระโดย:* $method\n'
            '📦 *รายการสินค้า:* ${items.length} รายการ\n'
            '$itemsList'
            '━━━━━━━━━━━━━━━━━━';
        TelegramService().sendMessage(msg);
      }
    } catch (e) {
      LoggerService.error('SalesRepository', 'Telegram Notify Error', e);
    }
  }
}
