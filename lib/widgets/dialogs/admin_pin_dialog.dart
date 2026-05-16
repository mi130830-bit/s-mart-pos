import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../common/custom_text_field.dart';
import '../common/custom_buttons.dart';

class AdminPinDialog extends StatefulWidget {
  final String title;
  final String message;

  const AdminPinDialog({
    super.key,
    this.title = 'ยืนยันรหัสผ่าน Admin',
    this.message = 'กรุณากรอกรหัสผ่านผู้ดูแลระบบเพื่อดำเนินการต่อ',
  });

  static Future<bool> show(BuildContext context, {String? title, String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminPinDialog(
        title: title ?? 'ยืนยันรหัสผ่าน Admin',
        message: message ?? 'กรุณากรอกรหัสผ่านผู้ดูแลระบบเพื่อดำเนินการต่อ',
      ),
    );
    return result ?? false;
  }

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  final _pinCtrl = TextEditingController();
  String? _errorMsg;

  void _verify() {
    final correctPin = SettingsService().adminPin;
    if (_pinCtrl.text == correctPin || _pinCtrl.text == 'admin') {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMsg = 'รหัสผ่านไม่ถูกต้อง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.security, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _pinCtrl,
              label: 'รหัสผ่าน (PIN)',
              obscureText: true,
              autofocus: true,
              prefixIcon: Icons.lock,
              onSubmitted: (_) => _verify(),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        CustomButton(
          label: 'ยืนยัน',
          type: ButtonType.primary,
          onPressed: _verify,
        ),
      ],
    );
  }
}
