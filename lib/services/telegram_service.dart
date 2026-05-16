import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'settings_service.dart';

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  // Settings Keys
  static const String keyEnabled = 'telegram_enabled';
  static const String keyToken = 'telegram_token';
  static const String keyChatId = 'telegram_chat_id';

  // Notification Toggles
  static const String keyNotifyPayment = 'telegram_notify_payment';
  static const String keyNotifyDebt = 'telegram_notify_debt';
  static const String keyNotifyShiftOpen = 'telegram_notify_shift_open';
  static const String keyNotifyShiftClose = 'telegram_notify_shift_close';
  static const String keyNotifyLowStock = 'telegram_notify_low_stock';
  static const String keyNotifyDeleteBill = 'telegram_notify_delete_bill';
  static const String keyNotifyAppOpen = 'telegram_notify_app_open';
  static const String keyNotifyHourlySales = 'telegram_notify_hourly_sales';
  static const String keyNotifyDelivery = 'telegram_notify_delivery'; // ✅
  static const String keyNotifyStockAdjust =
      'telegram_notify_stock_adjust'; // ✅
  static const String keyNotifyDeleteProduct =
      'telegram_notify_delete_product'; // ✅
  static const String keyNotifyBackup = 'telegram_notify_backup'; // ✅

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  Future<void> sendMessage(String message) async {
    // ✅ Use SettingsService (Synced with UI/DB)
    final settings = SettingsService();
    String token = settings.telegramToken;
    String chatId = settings.telegramChatId;
    bool enabled = settings.telegramEnabled;

    // 🚨 Failsafe: If empty, try reloading settings (maybe main init failed or race condition)
    if (token.isEmpty || chatId.isEmpty) {
      debugPrint('⚠️ Telegram Token/ChatID empty. Attempting force reload...');
      await settings.loadSettings();
      token = settings.telegramToken;
      chatId = settings.telegramChatId;
      enabled = settings.telegramEnabled;
    }

    debugPrint(
        '📨 Sending Telegram: Enabled=$enabled, TokenLen=${token.length}, ChatID=$chatId');

    if (!enabled || token.isEmpty || chatId.isEmpty) {
      debugPrint('❌ Telegram Cancelled: Missing config or disabled.');
      return;
    }

    final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
    try {
      // Use HTML parse_mode for better stability
      final response = await http.post(
        url,
        body: {
          'chat_id': chatId,
          'text': _escapeHtml(message),
          'parse_mode': 'HTML'
        },
      );
      if (response.statusCode != 200) {
        debugPrint('Telegram Send Error: ${response.body}');
        // If it still fails (e.g. invalid HTML entities), retry without parse_mode
        if (response.statusCode == 400) {
          debugPrint('Retrying without entities...');
          await http.post(
            url,
            body: {'chat_id': chatId, 'text': message},
          );
        }
      }
    } catch (e) {
      debugPrint('Telegram Connection Error: $e');
    }
  }

  Future<bool> testToken(String token, String chatId) async {
    if (token.isEmpty || chatId.isEmpty) return false;
    final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
    try {
      final response = await http.post(
        url,
        body: {
          'chat_id': chatId,
          'text': '🤖 *เชื่อมต่อสำเร็จ!* (Connected)\n'
              '━━━━━━━━━━━━━━━━━━\n'
              '✅ ระบบ POS เชื่อมต่อกับ Telegram นี้แล้ว\n'
              '📅 เวลา: ${DateTime.now().toString().substring(0, 16)}',
          'parse_mode': 'Markdown'
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram Test Error: $e');
      return false;
    }
  }

  // Helper to check specific notification setting
  Future<bool> shouldNotify(String key) async {
    final prefs = await SharedPreferences.getInstance();

    // Check Global Switch (Default False)
    if (!_getBool(prefs, keyEnabled)) return false;

    // Check Specific Setting with Defaults matching SettingsService
    bool defaultValue = false;
    if (key == keyNotifyPayment ||
        key == keyNotifyDebt ||
        key == keyNotifyDeleteBill ||
        key == keyNotifyDelivery ||
        key == keyNotifyStockAdjust ||
        key == keyNotifyBackup ||
        key == keyNotifyShiftClose) {
      defaultValue = true;
    }

    return _getBool(prefs, key, defaultValue: defaultValue);
  }

  bool _getBool(SharedPreferences prefs, String key,
      {bool defaultValue = false}) {
    // SettingsService saves everything as String, so we must handle that.
    // Try getBool first (legacy/native), if fail/null try String parse.
    try {
      final val = prefs.get(key); // Get dynamic
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  // ✅ New helper method to save secure credentials
  Future<void> saveCredentials(String token, String chatId) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: keyToken, value: token);
    await storage.write(key: keyChatId, value: chatId);
  }

  // 🧪 Simulation Method for Testing
  Future<void> verifySimulation() async {
    debugPrint('🚀 Starting Telegram Simulation...');

    // 1. Simulate Hourly Report
    await sendMessage('''
⏰ *รายงานยอดขายรายชั่วโมง* (Hourly Sales) [TEST]
━━━━━━━━━━━━━━━━━━
📅 *ช่วงเวลา:* 10:00 - 11:00
💰 *ยอดชั่วโมงนี้:* 1500.00 บาท (5 บิล)
📈 *ยอดสะสมวันนี้* (ถึง 11:00)
━━━━━━━━━━━━━━━━━━
💰 *ยอดรวม:* 5000.00 บาท
📄 *บิลรวม:* 20 ใบ
━━━━━━━━━━━━━━━━━━
''');

    await Future.delayed(const Duration(seconds: 1));

    // 2. Simulate Sales Notification with Items
    await sendMessage('''
💰 *แจ้งเตือนการขาย* (New Sale) [TEST]
━━━━━━━━━━━━━━━━━━
🧾 *บิล:* #9999
⏰ *เวลา:* 12:30
💵 *ยอดเงิน:* 250.00 บาท
� *รับเงิน:* 300.00 บาท
💸 *เงินทอน:* 50.00 บาท
�💳 *ชำระโดย:* Cash
📦 *รายการสินค้า:* 2 รายการ
- Coca Cola x 2
- Lay's Chips x 1
━━━━━━━━━━━━━━━━━━
''');

    await Future.delayed(const Duration(seconds: 1));

    // 3. Simulate Stock Adjustment
    await sendMessage('''
📦 *ปรับสต็อกสินค้า* (Stock Adjust) [TEST]
━━━━━━━━━━━━━━━━━━
สินค้า: Singha Water 600ml
เปลี่ยนแปลง: +12.0
คงเหลือ: 50.0
เหตุผล: ADJUST_ADD (Manual Restock)
━━━━━━━━━━━━━━━━━━
''');

    debugPrint('✅ Simulation Requests Sent.');
  }
}
