import 'package:flutter/material.dart';
import '../../../controllers/connection_settings_controller.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TelegramSettingsCard extends ConsumerWidget {
  const TelegramSettingsCard({super.key});

  void _showTelegramSettingsDialog(BuildContext context, WidgetRef ref) {
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
                  value: ref.watch(connectionSettingsProvider).tgNotifyPayment,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('payment', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนลูกหนี้ (Debt)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyDebt,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('debt', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนลบบิล (Delete Bill)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyDeleteBill,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('deleteBill', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนสต็อกต่ำ (Low Stock)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyLowStock,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('lowStock', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนงานขนส่ง (Delivery)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyDelivery,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('delivery', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนปรับสต็อก (Adjust)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyStockAdjust,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('stockAdjust', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนยอดขายรายชั่วโมง (Hourly)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyHourlySales,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('hourlySales', val!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('แจ้งเตือนเปิดแอป (App Open)'),
                  value: ref.watch(connectionSettingsProvider).tgNotifyAppOpen,
                  onChanged: (val) {
                    ref.read(connectionSettingsProvider.notifier).updateNotifySetting('appOpen', val!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _handleTest(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectionSettingsProvider.notifier);
    final token = controller.telegramTokenCtrl.text.trim();
    final chatId = controller.telegramChatIdCtrl.text.trim();

    if (token.isEmpty || chatId.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอก Token และ Chat ID',
        type: 'warning',
      );
      return;
    }

    AlertService.show(
      context: context,
      message: 'กำลังทดสอบการส่งข้อความ...',
      type: 'info',
    );

    final success = await controller.testTelegramToken();
    if (!context.mounted) return;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionSettingsProvider);
    final controller = ref.read(connectionSettingsProvider.notifier);
    return Card(
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
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('เปิดใช้งานการแจ้งเตือน'),
                  subtitle: const Text('ส่งข้อมูลยอดขายและการทำงาน'),
                  value: state.telegramEnabled,
                  onChanged: controller.updateTelegramEnabled,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                CustomTextField(
                  controller: controller.telegramTokenCtrl,
                  label: 'Bot Token',
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: controller.telegramChatIdCtrl,
                  label: 'Chat ID',
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    CustomButton(
                      onPressed: () => _handleTest(context, ref),
                      label: 'ทดสอบส่งข้อความ',
                      icon: Icons.send,
                      type: ButtonType.primary,
                      backgroundColor: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        onPressed: () => _showTelegramSettingsDialog(context, ref),
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
    );
  }
}
