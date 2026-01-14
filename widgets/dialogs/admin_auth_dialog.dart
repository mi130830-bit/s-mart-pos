import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';
import '../common/custom_text_field.dart';
import '../common/custom_buttons.dart';

class AdminAuthDialog extends StatefulWidget {
  final String title;
  final String message;

  const AdminAuthDialog({
    super.key,
    this.title = 'Authenticaton Required (ยืนยันสิทธิ์)',
    this.message = 'กรุณากรอกรหัสผ่าน Admin เพื่อดำเนินการต่อ',
  });

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AdminAuthDialog(),
    );
    return result ?? false;
  }

  @override
  State<AdminAuthDialog> createState() => _AdminAuthDialogState();
}

class _AdminAuthDialogState extends State<AdminAuthDialog> {
  final _userRepo = UserRepository();
  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final user = await _userRepo.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      if (mounted) {
        if (user != null && user.role == 'ADMIN') {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMsg = 'รหัสผ่านไม่ถูกต้อง หรือไม่ใช่สิทธิ์ Admin';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.security, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
              child: Text(widget.title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _usernameCtrl,
                label: 'Admin Username',
                prefixIcon: Icons.person,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _passwordCtrl,
                label: 'Password',
                obscureText: true,
                prefixIcon: Icons.lock,
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                onSubmitted: (_) => _verify(),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        CustomButton(
          label: _isLoading ? 'กำลังตรวจสอบ...' : 'ยืนยัน',
          icon: Icons.check_circle,
          type: ButtonType.primary,
          isLoading: _isLoading,
          onPressed: _verify,
        ),
      ],
    );
  }
}
