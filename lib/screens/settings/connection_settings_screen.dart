import 'package:flutter/material.dart';
import '../../controllers/connection_settings_controller.dart';
import '../../widgets/common/custom_buttons.dart';
import 'line_settings_widget.dart';
import 'widgets/api_settings_card.dart';
import 'widgets/telegram_settings_card.dart';
import 'widgets/firebase_settings_card.dart';
import 'widgets/ai_settings_card.dart';
import 'widgets/gps_settings_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionSettingsScreen extends ConsumerWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('การเชื่อมต่อ (Connections & API)')),
      body: Builder(
        builder: (context) {
          final state = ref.watch(connectionSettingsProvider);
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final notifier = ref.read(connectionSettingsProvider.notifier);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const ApiSettingsCard(),
              const SizedBox(height: 20),
              
              const TelegramSettingsCard(),
              const SizedBox(height: 20),
              
              const FirebaseSettingsCard(),
              const SizedBox(height: 20),
              
              const AiSettingsCard(),
              const SizedBox(height: 20),
              
              // Line OA (Pre-existing widget)
              const Card(child: LineSettingsWidget()),
              const SizedBox(height: 20),
              
              const GpsSettingsCard(),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: CustomButton(
                  onPressed: () {
                    notifier.saveSettings();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('บันทึกการตั้งค่าทั้งหมดแล้ว'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  label: 'บันทึกทั้งหมด',
                  type: ButtonType.primary,
                  backgroundColor: Colors.green[700],
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}
