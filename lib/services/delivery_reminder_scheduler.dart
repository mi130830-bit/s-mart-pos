import 'dart:async';
import 'package:flutter/material.dart';
import 'mysql_service.dart';
import 'telegram_service.dart';

/// ✅ DeliveryReminderScheduler
/// ส่งการแจ้งเตือนสิ้นเดือนเพื่อให้ทำรายงานขนส่ง
/// - ทุกวันสุดท้ายของเดือน เวลา 15:00–16:00 น.
/// - ส่งผ่าน Telegram (ถ้าตั้งค่าไว้)
/// - แสดง Dialog Popup ใน App สำหรับผู้ใช้ที่มีสิทธิ์ `delivery_report_reminder`
class DeliveryReminderScheduler {
  static final DeliveryReminderScheduler _instance =
      DeliveryReminderScheduler._internal();
  factory DeliveryReminderScheduler() => _instance;
  DeliveryReminderScheduler._internal();

  Timer? _timer;
  bool _isProcessing = false;

  // Key ใน system_settings สำหรับ distributed lock
  static const String _lockKey = 'delivery_reminder_last_sent';

  // Navigator key เพื่อแสดง Dialog จาก Background
  static GlobalKey<NavigatorState>? navigatorKey;

  void start() {
    if (_timer != null && _timer!.isActive) return;
    debugPrint('⏰ [DeliveryReminder] Starting... (checks every 30 min)');
    _checkAndRemind(); // Run immediately on start
    _timer = Timer.periodic(const Duration(minutes: 30), (_) {
      _checkAndRemind();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 [DeliveryReminder] Stopped.');
  }

  Future<void> _checkAndRemind() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final db = MySQLService();
      if (!db.isConnected()) return;

      final now = DateTime.now();

      // 1. ตรวจสอบว่าเป็นวันสุดท้ายของเดือนหรือไม่
      final lastDayOfMonth =
          DateTime(now.year, now.month + 1, 0); // วันสุดท้ายของเดือนนี้
      if (now.day != lastDayOfMonth.day) return;

      // 2. ตรวจสอบว่าเป็นช่วง 15:00–16:00 น.
      if (now.hour < 15 || now.hour >= 16) return;

      // 3. Distributed lock — ป้องกัน Multi-Device ส่งซ้ำ
      final targetKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // เพิ่ม key ถ้าไม่มี
      await db.execute(
          "INSERT IGNORE INTO system_settings (setting_key, setting_value) VALUES (:key, '')",
          {'key': _lockKey});

      // ลองกันล็อครายเดือน (update จาก value เดิมที่ไม่ใช่ targetKey)
      final result = await db.execute(
          "UPDATE system_settings SET setting_value = :newVal WHERE setting_key = :key AND setting_value != :checkVal",
          {'newVal': targetKey, 'key': _lockKey, 'checkVal': targetKey});

      if (result.affectedRows == BigInt.zero) {
        // Already sent this month
        return;
      }

      debugPrint('📢 [DeliveryReminder] Sending end-of-month reminder...');

      // 4. ส่ง Telegram
      await _sendTelegramReminder(db, now);

      // 5. แสดง In-App Dialog (สำหรับผู้ใช้ที่มีสิทธิ์)
      await _showInAppDialog(db, now);
    } catch (e) {
      debugPrint('⚠️ [DeliveryReminder] Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _sendTelegramReminder(MySQLService db, DateTime now) async {
    try {
      final telegram = TelegramService();
      final isEnabled =
          await telegram.shouldNotify(TelegramService.keyNotifyHourlySales);
      if (!isEnabled) return;

      final monthName = _thaiMonth(now.month);
      final yearBE = now.year + 543;

      final msg = '''
📊 *แจ้งเตือนสรุปรายงานขนส่ง (สิ้นเดือน)*
━━━━━━━━━━━━━━━━━━
📅 *เดือน:* $monthName $yearBE
🚚 ถึงเวลาสรุปรายงานการส่งสินค้าประจำเดือนแล้ว!
━━━━━━━━━━━━━━━━━━
📋 *ขั้นตอน:*
1. เปิดหน้า "รายงานการส่งสินค้า" บน POS Desktop
2. เลือกช่วงเวลาเป็น "เดือนนี้"  
3. กด Export Excel เพื่อดาวน์โหลดรายงาน
━━━━━━━━━━━━━━━━━━
''';

      await telegram.sendMessage(msg);
      debugPrint('✅ [DeliveryReminder] Telegram sent.');
    } catch (e) {
      debugPrint('⚠️ [DeliveryReminder] Telegram error: $e');
    }
  }

  Future<void> _showInAppDialog(MySQLService db, DateTime now) async {
    try {
      // หาผู้ใช้ที่มีสิทธิ์ delivery_report_reminder
      final permUsers = await db.query('''
        SELECT u.id, u.displayName, u.username
        FROM user u
        JOIN user_permission p ON u.id = p.userId
        WHERE p.permissionKey = 'delivery_report_reminder'
          AND p.isAllowed = 1
          AND u.isActive = 1
      ''');

      if (permUsers.isEmpty) return;

      // แสดง Dialog ที่ navigator หลัก (ถ้ามี)
      final navKey = navigatorKey;
      if (navKey == null || navKey.currentState == null) return;

      final context = navKey.currentContext;
      if (context == null) return;

      final monthName = _thaiMonth(now.month);
      final yearBE = now.year + 543;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: navKey.currentContext!,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '⏰ แจ้งเตือนสิ้นเดือน',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ถึงเวลาสรุปรายงานการส่งสินค้า\nประจำเดือน $monthName $yearBE แล้ว!',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📋 วิธีทำ:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('1. ไปที่เมนู "รายงานขนส่ง"'),
                      Text('2. เลือกช่วงเวลา "เดือนนี้"'),
                      Text('3. กดปุ่ม Export Excel 📥'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ปิด'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('ไปที่รายงาน'),
                onPressed: () {
                  Navigator.pop(ctx);
                  // Navigate to delivery report screen
                  // This is handled by the caller via navigating in main_screen
                  _navigateToReport(navKey);
                },
              ),
            ],
          ),
        );
      });
    } catch (e) {
      debugPrint('⚠️ [DeliveryReminder] Dialog error: $e');
    }
  }

  void _navigateToReport(GlobalKey<NavigatorState> navKey) {
    // Trigger navigation via GlobalKey
    // The actual route is defined in main_screen.dart
    debugPrint('📍 [DeliveryReminder] Navigate to delivery report requested.');
    // We use a simple approach: just show a snackbar guiding the user
    final ctx = navKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text(
              '📦 กรุณาไปที่เมนู "รายงานขนส่ง" ในแถบด้านซ้าย'),
          backgroundColor: const Color(0xFF1E3A5F),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'ตกลง',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // ✅ Manual trigger (สำหรับ test)
  Future<void> triggerNow() async {
    debugPrint('🔔 [DeliveryReminder] Manual trigger requested.');
    final db = MySQLService();
    if (!db.isConnected()) {
      debugPrint('⚠️ [DeliveryReminder] DB not connected.');
      return;
    }
    final now = DateTime.now();
    await _sendTelegramReminder(db, now);
    await _showInAppDialog(db, now);
  }

  String _thaiMonth(int month) {
    const months = [
      '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
      'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
      'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    return months[month];
  }
}
