import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import 'notification_log_screen.dart';
import '../../services/alert_service.dart';

class LineSettingsWidget extends StatefulWidget {
  const LineSettingsWidget({super.key});

  @override
  State<LineSettingsWidget> createState() => _LineSettingsWidgetState();
}

class _LineSettingsWidgetState extends State<LineSettingsWidget> {
  final _tokenCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _tokenCtrl.text = SettingsService().lineChannelAccessToken;
    });
  }

  Future<void> _saveToken() async {
    setState(() => _isLoading = true);
    try {
      if (_tokenCtrl.text.trim().isEmpty) {
        // Clear if empty
        await SettingsService().remove('line_channel_access_token');
      } else {
        // Use set() directly to await the DB write
        await SettingsService()
            .set('line_channel_access_token', _tokenCtrl.text.trim());
      }

      if (mounted) {
        AlertService.show(
          context: context,
          message: 'บันทึก Line Token เรียบร้อย ✅',
          type: 'success',
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Line Official Account (Line OA)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'นำ Channel Access Token จาก Line Dev Console มาใส่ที่นี่ เพื่อให้ระบบส่งแจ้งเตือนได้',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _tokenCtrl,
            label: 'Channel Access Token',
            maxLines: 3,
            prefixIcon: Icons.key,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationLogScreen()),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('ประวัติการส่ง (Logs)'),
                ),
                const SizedBox(width: 8),
                CustomButton(
                  onPressed: _isLoading ? null : _saveToken,
                  label: 'บันทึก Token',
                  icon: Icons.save,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
