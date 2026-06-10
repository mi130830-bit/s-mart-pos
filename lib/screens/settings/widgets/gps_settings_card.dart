import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../controllers/connection_settings_controller.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GpsSettingsCard extends ConsumerWidget {
  const GpsSettingsCard({super.key});

  Future<void> _handleTest(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectionSettingsProvider.notifier);
    final lat = controller.shopLatCtrl.text.trim();
    final lng = controller.shopLngCtrl.text.trim();
    if (lat.isEmpty || lng.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอกพิกัดก่อน',
        type: 'warning',
      );
      return;
    }
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(connectionSettingsProvider.notifier);
    return Card(
      child: Column(
        children: [
          Container(
            color: Colors.green[800],
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: const Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.white),
                SizedBox(width: 10),
                Text('GPS ต้นทาง',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ตั้งค่าพิกัด GPS ต้นทาง (ร้าน) เพื่อใช้อ้างอิงและคำนวณระยะทางจริงในรายงานการส่งของ',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: controller.shopLatCtrl,
                        label: 'ละติจูดร้าน (Latitude)',
                        hint: 'เช่น 16.160189',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: controller.shopLngCtrl,
                        label: 'ลองจิจูดร้าน (Longitude)',
                        hint: 'เช่น 100.802307',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomButton(
                  onPressed: () => _handleTest(context, ref),
                  label: 'ตรวจสอบตำแหน่งบน Google Maps',
                  icon: Icons.map_outlined,
                  type: ButtonType.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
