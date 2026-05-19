// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../general_settings_screen.dart';

/// Security card: Admin PIN dialog + Void/StockAdjust switches.
extension SecuritySettingsCardExtension on _GeneralSettingsScreenState {
  // ─── Dialog ──────────────────────────────────────────────────────────────────

  void _showEditPinDialog() {
    final ctrl = TextEditingController(text: _adminPin);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ตั้งค่ารหัสแอดมิน'),
        content: CustomTextField(
          controller: ctrl,
          label: 'รหัสผ่านใหม่',
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          CustomButton(
            label: 'บันทึก',
            type: ButtonType.primary,
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                setState(() => _adminPin = ctrl.text);
                _saveSettings();
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ─── Widget ──────────────────────────────────────────────────────────────────

  Widget _buildSecurityCard() {
    return Card(
      child: Column(
        children: [
          // Admin PIN
          ListTile(
            leading: const Icon(Icons.password, color: Colors.red),
            title: const Text('รหัสแอดมิน (Admin PIN)'),
            subtitle: const Text('ใช้สำหรับลบข้อมูลหรือทำรายการที่ต้องขออนุมัติ'),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('***', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Icon(Icons.edit, size: 18),
              ],
            ),
            onTap: _showEditPinDialog,
          ),
          const Divider(),
          // Require admin for Void
          SwitchListTile(
            title: const Text('ต้องใช้รหัสแอดมินในการลบบิล (Void)'),
            secondary: const Icon(Icons.delete_forever, color: Colors.orange),
            value: _requireAdminForVoid,
            onChanged: (val) {
              setState(() => _requireAdminForVoid = val);
              _saveSettings();
            },
          ),
          const Divider(),
          // Require admin for Stock Adjust
          SwitchListTile(
            title: const Text('ต้องใช้รหัสแอดมินในการปรับสต็อก'),
            secondary: const Icon(Icons.inventory, color: Colors.blue),
            value: _requireAdminForStockAdjust,
            onChanged: (val) {
              setState(() => _requireAdminForStockAdjust = val);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }
}
