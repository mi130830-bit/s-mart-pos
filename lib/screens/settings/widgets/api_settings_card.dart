import 'package:flutter/material.dart';
import '../../../../controllers/connection_settings_controller.dart';
import '../../../../services/alert_service.dart';
import '../../../../widgets/common/custom_text_field.dart';
import '../../../../widgets/common/custom_buttons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiSettingsCard extends ConsumerWidget {
  const ApiSettingsCard({super.key});

  Future<void> _handleTest(BuildContext context, WidgetRef ref) async {
    AlertService.show(
      context: context,
      message: 'กำลังทดสอบการเชื่อมต่อ...',
      type: 'info',
    );

    final error = await ref.read(connectionSettingsProvider.notifier).testApiConnection();
    if (!context.mounted) return;

    if (error == null) {
      AlertService.show(
        context: context,
        message: 'เชื่อมต่อสำเร็จ! (200 OK)',
        type: 'success',
      );
    } else if (error.startsWith('พบ Server')) {
      AlertService.show(
        context: context,
        message: error,
        type: 'warning',
      );
    } else {
      AlertService.show(
        context: context,
        message: error,
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
            color: Colors.teal[800],
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: const Row(
              children: [
                Icon(Icons.dns, color: Colors.white),
                SizedBox(width: 10),
                Text('Backend API Server',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'ใช้สำหรับเชื่อมต่อกับระบบ Backend (Node/Shelf) เพื่อส่ง Line OA\n(หากใช้เครื่องลูกข่าย ให้ใส่ IP ของเครื่องแม่ เช่น http://192.168.1.100:8080/api/v1)',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: controller.apiUrlCtrl,
                  label: '💻 API URL (เฉพาะเครื่องนี้)',
                  hint: 'http://localhost:8080/api/v1',
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    CustomButton(
                      onPressed: () => _handleTest(context, ref),
                      label: 'ทดสอบการเชื่อมต่อ',
                      icon: Icons.network_check,
                      type: ButtonType.primary,
                      backgroundColor: Colors.teal[700],
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
