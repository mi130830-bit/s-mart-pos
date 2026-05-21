import 'package:flutter/material.dart';
import '../../../models/user.dart' as model;
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../controllers/user_management_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  final model.User user;

  const ChangePasswordDialog({
    super.key,
    required this.user,
  });

  static void show(BuildContext context, model.User user) {
    showDialog(
      context: context,
      builder: (ctx) => ChangePasswordDialog(user: user),
    );
  }

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  bool _isPassVisible = false;
  bool _isConfirmVisible = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_passCtrl.text.isEmpty) return;

    if (_passCtrl.text != _confirmCtrl.text) {
      AlertService.show(
        context: context,
        message: 'รหัสผ่านไม่ตรงกัน',
        type: 'error',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await ref.read(userManagementProvider.notifier).changePassword(widget.user.id, _passCtrl.text);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          AlertService.show(
            context: context,
            message: 'เปลี่ยนรหัสผ่านเรียบร้อย',
            type: 'success',
          );
        } else {
          AlertService.show(
            context: context,
            message: 'เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน',
            type: 'error',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('เปลี่ยนรหัสผ่าน: ${widget.user.username}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            controller: _passCtrl,
            obscureText: !_isPassVisible,
            label: 'รหัสผ่านใหม่',
            prefixIcon: Icons.lock,
            suffixIcon: IconButton(
              icon: Icon(
                _isPassVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _isPassVisible = !_isPassVisible),
            ),
          ),
          const SizedBox(height: 15),
          CustomTextField(
            controller: _confirmCtrl,
            obscureText: !_isConfirmVisible,
            label: 'ยืนยันรหัสผ่านใหม่',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
            ),
          ),
        ],
      ),
      actions: [
        CustomButton(
          label: 'ยกเลิก',
          type: ButtonType.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: _isSaving ? 'กำลังบันทึก...' : 'บันทึก',
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
