import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/settings_service.dart';
import '../../services/alert_service.dart';
import '../../services/telegram_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  bool _isLoading = true;

  // Telegram
  bool _telegramEnabled = false;
  final TextEditingController _telegramTokenCtrl = TextEditingController();
  final TextEditingController _telegramChatIdCtrl = TextEditingController();
  bool _tgNotifyPayment = true;
  bool _tgNotifyDebt = true;
  bool _tgNotifyDeleteBill = true;
  bool _tgNotifyLowStock = false;
  bool _tgNotifyDelivery = true;
  bool _tgNotifyStockAdjust = true;
  bool _tgNotifyAppOpen = false;
  bool _tgNotifyHourlySales = false;

  // Firebase
  final TextEditingController _firebaseEmailCtrl = TextEditingController();
  final TextEditingController _firebasePasswordCtrl = TextEditingController();

  // AI
  final TextEditingController _geminiApiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    // Assuming settings are already loaded in memory by app init
    setState(() {
      // Telegram
      _telegramEnabled = settings.telegramEnabled;
      _telegramTokenCtrl.text = settings.telegramToken;
      _telegramChatIdCtrl.text = settings.telegramChatId;
      _tgNotifyPayment = settings.telegramNotifyPayment;
      _tgNotifyDebt = settings.telegramNotifyDebt;
      _tgNotifyDeleteBill = settings.telegramNotifyDeleteBill;
      _tgNotifyLowStock = settings.telegramNotifyLowStock;
      _tgNotifyDelivery = settings.telegramNotifyDelivery;
      _tgNotifyStockAdjust = settings.telegramNotifyStockAdjust;
      _tgNotifyAppOpen = settings.telegramNotifyAppOpen;
      _tgNotifyHourlySales = settings.telegramNotifyHourlySales;

      // Firebase
      _firebaseEmailCtrl.text = settings.firebaseAuthEmail;
      _firebasePasswordCtrl.text = settings.firebaseAuthPassword;

      // AI
      _geminiApiKeyCtrl.text = settings.geminiApiKey;

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = SettingsService();

    // Telegram
    await settings.set('telegram_enabled', _telegramEnabled);
    await settings.set('telegram_token', _telegramTokenCtrl.text);
    await settings.set('telegram_chat_id', _telegramChatIdCtrl.text);
    await settings.set('telegram_notify_payment', _tgNotifyPayment);
    await settings.set('telegram_notify_debt', _tgNotifyDebt);
    await settings.set('telegram_notify_delete_bill', _tgNotifyDeleteBill);
    await settings.set('telegram_notify_low_stock', _tgNotifyLowStock);
    await settings.set('telegram_notify_delivery', _tgNotifyDelivery);
    await settings.set('telegram_notify_stock_adjust', _tgNotifyStockAdjust);
    await settings.set('telegram_notify_app_open', _tgNotifyAppOpen);
    await settings.set('telegram_notify_hourly_sales', _tgNotifyHourlySales);

    // Firebase
    await settings.set('firebase_auth_email', _firebaseEmailCtrl.text);
    await settings.set('firebase_auth_password', _firebasePasswordCtrl.text);

    // AI
    await settings.set('gemini_api_key', _geminiApiKeyCtrl.text);

    if (mounted) {
      AlertService.show(
        context: context,
        message: 'บันทึกการตั้งค่าการเชื่อมต่อแล้ว',
        type: 'success',
      );
    }
  }

  Future<void> _testTelegramToken() async {
    final token = _telegramTokenCtrl.text.trim();
    final chatId = _telegramChatIdCtrl.text.trim();

    if (token.isEmpty || chatId.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอก Token และ Chat ID',
        type: 'warning',
      );
      return;
    }

    // Temporarily save to ensure service uses latest (though service might use params if passed)
    // TelegramService().testToken takes token/chatId as args.
    if (mounted) {
      AlertService.show(
        context: context,
        message: 'กำลังทดสอบการส่งข้อความ...',
        type: 'info',
      );
    }

    final success = await TelegramService().testToken(token, chatId);

    if (!mounted) return;
    if (success) {
      AlertService.show(
        context: context,
        message: 'ทดสอบสำเร็จ! โปรดเช็คข้อความใน Telegram',
        type: 'success',
      );
    } else {
      AlertService.show(
        context: context,
        message: 'ทดสอบล้มเหลว! กรุณาตรวจสอบ Token และ Chat ID',
        type: 'error',
      );
    }
  }

  Future<void> _testFirebaseConnection() async {
    final email = _firebaseEmailCtrl.text.trim();
    final password = _firebasePasswordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอก Email และ Password ให้ครบถ้วน',
        type: 'warning',
      );
      return;
    }

    if (mounted) {
      AlertService.show(
        context: context,
        message: 'กำลังทดสอบการเชื่อมต่อ...',
        type: 'info',
      );
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        AlertService.show(
          context: context,
          message:
              'เชื่อมต่อสำเร็จ! (Logged in as ${FirebaseAuth.instance.currentUser?.email})',
          type: 'success',
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'เชื่อมต่อล้มเหลว: $e',
          type: 'error',
        );
      }
    }
  }

  void _showTelegramSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDlg) {
        return AlertDialog(
          title: const Text('ตั้งค่าการแจ้งเตือน (Notification Config)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('แจ้งเตือนเมื่อคิดเงิน (Payment)'),
                  value: _tgNotifyPayment,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyPayment = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนลูกหนี้ (Debt)'),
                  value: _tgNotifyDebt,
                  onChanged: (val) => setStateDlg(() => _tgNotifyDebt = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนลบบิล (Delete Bill)'),
                  value: _tgNotifyDeleteBill,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyDeleteBill = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนสต็อกต่ำ (Low Stock)'),
                  value: _tgNotifyLowStock,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyLowStock = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนงานขนส่ง (Delivery)'),
                  value: _tgNotifyDelivery,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyDelivery = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนปรับสต็อก (Adjust)'),
                  value: _tgNotifyStockAdjust,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyStockAdjust = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนยอดขายรายชั่วโมง (Hourly)'),
                  value: _tgNotifyHourlySales,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyHourlySales = val!),
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนเปิดแอป (App Open)'),
                  value: _tgNotifyAppOpen,
                  onChanged: (val) =>
                      setStateDlg(() => _tgNotifyAppOpen = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ตกลง')),
          ],
        );
      }),
    ).then((_) {
      // Refresh parent state if needed, usually we just save on "Save"
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การเชื่อมต่อ (Connections & API)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Telegram
                Card(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.blue[800],
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: const Row(
                          children: [
                            Icon(Icons.telegram, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Telegram Notification',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('เปิดใช้งานการแจ้งเตือน'),
                              subtitle:
                                  const Text('ส่งข้อมูลยอดขายและการทำงาน'),
                              value: _telegramEnabled,
                              onChanged: (val) {
                                setState(() => _telegramEnabled = val);
                                _saveSettings();
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            const Divider(),
                            CustomTextField(
                              controller: _telegramTokenCtrl,
                              label: 'Bot Token',
                              onChanged: (_) => _saveSettings(),
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _telegramChatIdCtrl,
                              label: 'Chat ID',
                              onChanged: (_) => _saveSettings(),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                CustomButton(
                                  onPressed: _testTelegramToken,
                                  label: 'ทดสอบส่งข้อความ',
                                  icon: Icons.send,
                                  type: ButtonType.primary,
                                  backgroundColor: Colors.blue,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CustomButton(
                                    onPressed: _showTelegramSettingsDialog,
                                    label: 'เลือกหัวข้อแจ้งเตือน',
                                    icon: Icons.checklist,
                                    type: ButtonType.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Firebase
                Card(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.orange[800],
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud_sync, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Firebase (S-Link App)',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'ใช้สำหรับเชื่อมต่อกับแอป S-Link (Mobile) เพื่อส่งงานและแจ้งเตือน',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 15),
                            CustomTextField(
                              controller: _firebaseEmailCtrl,
                              label: 'Admin Email',
                              onChanged: (_) => _saveSettings(),
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _firebasePasswordCtrl,
                              label: 'Admin Password',
                              obscureText: true,
                              onChanged: (_) => _saveSettings(),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                CustomButton(
                                  onPressed: _testFirebaseConnection,
                                  label: 'ทดสอบการเชื่อมต่อ (Test)',
                                  icon: Icons.wifi_protected_setup,
                                  type: ButtonType.primary,
                                  backgroundColor: Colors.orange[700],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // AI / Gemini
                Card(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.deepPurple[800],
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: const Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.white),
                            SizedBox(width: 10),
                            Text('AI Assistant (Gemini)',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'ใช้สำหรับวิเคราะห์ยอดขายและช่วยตอบคำถาม',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 15),
                            CustomTextField(
                              controller: _geminiApiKeyCtrl,
                              label: 'Gemini API Key',
                              onChanged: (_) => _saveSettings(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: CustomButton(
                    onPressed: _saveSettings,
                    label: 'บันทึกทั้งหมด',
                    type: ButtonType.primary,
                    backgroundColor: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
