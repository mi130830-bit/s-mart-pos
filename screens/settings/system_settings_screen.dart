import 'package:flutter/material.dart';

import '../../services/system/clean_database_service.dart';
import '../../services/alert_service.dart';
import '../../services/settings_service.dart';
import '../users/user_management_screen.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';
// import 'line_settings_widget.dart'; // Moved to connection_settings_screen.dart

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  Future<void> _showClearOldDataDialog(BuildContext context) async {
    String selectedType = 'SALES'; // SALES, BILLING
    DateTime selectedDate = DateTime.now();
    bool isAll = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('ล้างข้อมูล (Clear Data)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('เลือกประเภทข้อมูลที่ต้องการลบ:'),
                DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'SALES', child: Text('ยอดขาย (Sales / Orders)')),
                    DropdownMenuItem(
                        value: 'BILLING',
                        child: Text('เอกสารวางบิล/ลูกหนี้ (Billing)')),
                  ],
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('ลบทั้งหมด (ไม่จำกัดที่วันที่)'),
                  value: isAll,
                  onChanged: (v) => setState(() => isAll = v!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (!isAll) ...[
                  const Text('ลบข้อมูลที่เก่ากว่าหรือเท่ากับวันที่:'),
                  ListTile(
                    title: Text('${selectedDate.toLocal()}'.split(' ')[0]),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ],
                Text(
                    isAll
                        ? 'หมายเหตุ: ข้อมูลประเภทนี้จะถูกลบทั้งหมดถาวร'
                        : 'หมายเหตุ: ข้อมูลที่เลือกถึงวันที่กำหนดจะถูกลบถาวร',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก')),
              CustomButton(
                label: 'ลบข้อมูล',
                type: ButtonType.danger,
                onPressed: () async {
                  Navigator.pop(ctx);
                  _confirmAndExecuteClear(
                      context, selectedType, selectedDate, isAll);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndExecuteClear(
      BuildContext context, String type, DateTime date, bool isAll) async {
    final dateStr = '${date.toLocal()}'.split(' ')[0];
    final title = isAll ? 'ยืนยันการลบทิ้งทั้งหมด?' : 'ยืนยันการลบ?';
    final content = isAll
        ? 'คุณต้องการลบข้อมูล $type ทั้งหมดออกจากระบบใช่หรือไม่?'
        : 'คุณต้องการลบข้อมูล $type \nที่เก่ากว่าหรือเท่ากับวันที่ $dateStr ใช่หรือไม่?';

    final confirm = await ConfirmDialog.show(
      context,
      title: title,
      content: content,
      isDestructive: true,
      confirmText: 'ยืนยัน',
    );

    if (confirm == true && context.mounted) {
      try {
        int count = 0;
        final service = CleanDatabaseService();
        if (type == 'SALES') {
          count = await service.deleteOldSales(date, isAll: isAll);
        } else {
          count = await service.deleteOldBilling(date, isAll: isAll);
        }

        if (context.mounted) {
          AlertService.show(
            context: context,
            message: 'สำเร็จ! ลบข้อมูลไปแล้วจำนวนมาก (affected rows: $count)',
            type: 'success',
          );
        }
      } catch (e) {
        if (context.mounted) {
          AlertService.show(
            context: context,
            message: 'Error: $e',
            type: 'error',
          );
        }
      }
    }
  }

  Future<void> _showFactoryResetDialog(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการล้างข้อมูล?',
      content:
          'คำเตือน: การกระทำนี้ไม่สามารถย้อนกลับได้\nข้อมูลทั้งหมดจะถูกลบถาวร (ลูกค้า, สินค้า, ยอดขาย, บัญชี)\n\nคุณแน่ใจหรือไม่?',
      isDestructive: true,
      confirmText: 'ยืนยันลบข้อมูล',
    );

    if (confirmed == true && context.mounted) {
      // Second Confirmation
      final doubleConfirmed = await ConfirmDialog.show(
        context,
        title: 'ยืนยันครั้งสุดท้าย!',
        content: 'ระบบจะลบข้อมูลทั้งหมดจริงๆ \nกรุณากด "ยืนยัน" เพื่อดำเนินการ',
        isDestructive: true,
        confirmText: 'ลบทุกอย่างเดี๋ยวนี้',
      );

      if (doubleConfirmed == true && context.mounted) {
        try {
          await CleanDatabaseService().clearAllData();
          if (context.mounted) {
            if (context.mounted) {
              AlertService.show(
                context: context,
                message: 'ล้างข้อมูลเรียบร้อยแล้ว',
                type: 'success',
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            if (context.mounted) {
              AlertService.show(
                context: context,
                message: 'Error: $e',
                type: 'error',
              );
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ระบบและความปลอดภัย (System)')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_person, color: Colors.red),
                  title: const Text('จัดการผู้ใช้งาน (User Management)'),
                  subtitle:
                      const Text('เพิ่ม/ลบ พนักงาน, เปลี่ยนรหัสผ่าน Admin'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserManagementScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('การตั้งค่าความปลอดภัย (Security)',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          const Card(
            child: SecuritySettingsWidget(),
          ),
          const SizedBox(height: 20),
          const Text('พื้นที่อันตราย (Dangerous Zone)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 10),
          Card(
            color: Colors.red.shade50,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.orange),
                  title: const Text('ลบข้อมูลเก่าตามช่วงเวลา (Clear Old Data)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle:
                      const Text('เลือกลบยอดขายหรือบิลเก่ากว่าวันที่กำหนด'),
                  onTap: () => _showClearOldDataDialog(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('ล้างข้อมูลทั้งหมด (Factory Reset)',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'ลบข้อมูลลูกค้า, สินค้า, ยอดขาย และบัญชีทั้งหมด'),
                  onTap: () => _showFactoryResetDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Center(
              child: Text('Version 1.0.6 (Build 2025)',
                  style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

class SecuritySettingsWidget extends StatefulWidget {
  const SecuritySettingsWidget({super.key});

  @override
  State<SecuritySettingsWidget> createState() => _SecuritySettingsWidgetState();
}

class _SecuritySettingsWidgetState extends State<SecuritySettingsWidget> {
  bool _requireVoid = false;
  bool _requireStockAdjust = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = SettingsService();
    setState(() {
      _requireVoid = settings.requireAdminForVoid;
      _requireStockAdjust = settings.requireAdminForStockAdjust;
    });
  }

  Future<void> _toggleVoid(bool value) async {
    setState(() => _requireVoid = value);
    await SettingsService().set('require_admin_for_void', value);
  }

  Future<void> _toggleStockAdjust(bool value) async {
    setState(() => _requireStockAdjust = value);
    await SettingsService().set('require_admin_for_stock_adjust', value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('บังคับรหัสผ่านเมื่อลบบิล (Void Bill)'),
            subtitle: const Text('ต้องใช้รหัส Admin เพื่อลบบิลขาย'),
            value: _requireVoid,
            onChanged: _toggleVoid,
            secondary: const Icon(Icons.lock_outline, color: Colors.orange),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('บังคับรหัสผ่านแก้สต็อก (Stock Adjust & Edit)'),
            subtitle: const Text(
                'ต้องใช้รหัส Admin เพื่อปรับปรุงยอดสต็อก หรือแก้ไขจำนวนในหน้าสินค้า'),
            value: _requireStockAdjust,
            onChanged: _toggleStockAdjust,
            secondary: const Icon(Icons.inventory, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
