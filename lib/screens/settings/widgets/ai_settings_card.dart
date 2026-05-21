import 'package:flutter/material.dart';
import '../../../../controllers/connection_settings_controller.dart';
import '../../../../widgets/common/custom_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiSettingsCard extends ConsumerWidget {
  const AiSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(connectionSettingsProvider.notifier);
    return Card(
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
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  controller: controller.geminiApiKeyCtrl,
                  label: 'Gemini API Key',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
