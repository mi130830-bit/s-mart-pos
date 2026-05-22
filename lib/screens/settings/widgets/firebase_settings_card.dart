import 'package:flutter/material.dart';
import '../../../controllers/connection_settings_controller.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirebaseSettingsCard extends ConsumerWidget {
  const FirebaseSettingsCard({super.key});

  Future<void> _handleTest(BuildContext context, WidgetRef ref) async {
    AlertService.show(
      context: context,
      message: 'กำลังทดสอบการเชื่อมต่อ...',
      type: 'info',
    );

    final error = await ref.read(connectionSettingsProvider.notifier).testFirebaseConnection();
    if (!context.mounted) return;

    if (error == null) {
      AlertService.show(
        context: context,
        message: 'เชื่อมต่อสำเร็จ!',
        type: 'success',
      );
    } else if (error.startsWith('กรุณากรอก')) {
      AlertService.show(
        context: context,
        message: error,
        type: 'warning',
      );
    } else {
      AlertService.show(
        context: context,
        message: 'เชื่อมต่อล้มเหลว: $error',
        type: 'error',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(connectionSettingsProvider.notifier);
    return Card(
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
                Text('Firebase (S_MartPOS Connect)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'ใช้สำหรับเชื่อมต่อกับแอป S_MartPOS (Mobile) เพื่อส่งงานและแจ้งเตือน',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: controller.firebaseEmailCtrl,
                  label: 'Admin Email',
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: controller.firebasePasswordCtrl,
                  label: 'Admin Password',
                  obscureText: true,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    CustomButton(
                      onPressed: () => _handleTest(context, ref),
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
    );
  }
}
