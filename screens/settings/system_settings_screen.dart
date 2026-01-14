import 'package:flutter/material.dart';
import 'dart:io'; // Added
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart'; // Added

import '../../services/system/clean_database_service.dart';
import '../../services/system/backup_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/mysql_service.dart'; // Added
import '../../services/settings_service.dart';
import '../users/user_management_screen.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

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
          const Text('การสำรองข้อมูล (Database)',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            child: BackupSettingsWidget(),
          ),
          const SizedBox(height: 20),
          const Text('ตั้งค่าฐานข้อมูล (Database Config)',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          const Card(
            child: DatabaseSettingsWidget(),
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

class BackupSettingsWidget extends StatefulWidget {
  const BackupSettingsWidget({super.key});

  @override
  State<BackupSettingsWidget> createState() => _BackupSettingsWidgetState();
}

class _BackupSettingsWidgetState extends State<BackupSettingsWidget> {
  String _interval = 'NONE';
  String _destination = 'LOCAL';
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _interval = prefs.getString('backup_interval_type') ?? 'NONE';
      _destination = prefs.getString('backup_destination') ?? 'LOCAL';
    });
  }

  Future<void> _saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _loadSettings();
  }

  Future<void> _manualBackup() async {
    setState(() => _isBackingUp = true);
    try {
      String? savePath;

      // If Local, Ask for Save Location
      if (_destination == 'LOCAL') {
        // Temporarily hide loading to show picker smoothly? No context switch needed.
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'บันทึกไฟล์ Backup (Save Backup)',
          fileName: 'backup_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile == null) {
          // User canceled
          if (mounted) setState(() => _isBackingUp = false);
          return;
        }
        savePath = outputFile;
      }

      final service = BackupService();
      final file = await service.createBackup(customPath: savePath);

      if (file != null) {
        if (_destination == 'DRIVE') {
          final drive = GoogleDriveService();
          final ok = await drive.uploadBackup(file);
          if (mounted) {
            if (mounted) {
              AlertService.show(
                context: context,
                message: ok
                    ? 'Backup to Drive Success'
                    : 'Drive Upload Failed (Saved Locally)',
                type: ok ? 'success' : 'warning',
              );
            }
          }
        } else {
          if (mounted) {
            if (mounted) {
              AlertService.show(
                context: context,
                message: 'Backup Saved Successfully: ${file.path}',
                type: 'success',
              );
            }
          }
        }
      } else {
        if (mounted) {
          if (mounted) {
            AlertService.show(
              context: context,
              message: 'Backup Failed',
              type: 'error',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Backup Error: $e');
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreData() async {
    try {
      // 1. Pick Json File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        if (!mounted) return;

        // 2. Confirm Dialog
        final confirm = await ConfirmDialog.show(
          context,
          title: 'ยืนยันการกู้คืนข้อมูล?',
          content:
              'ข้อมูลปัจจุบันทั้งหมดจะถูกลบและแทนที่ด้วยข้อมูลจากไฟล์ Backup\n\nแน่ใจหรือไม่?',
          isDestructive: true,
          confirmText: 'ยืนยันกู้คืน',
        );

        if (confirm == true && mounted) {
          setState(() => _isBackingUp = true); // Reuse loading state

          final service = BackupService();
          final success = await service.restoreBackup(file);

          if (mounted) {
            setState(() => _isBackingUp = false);
            AlertService.show(
              context: context,
              message: success
                  ? 'กู้คืนข้อมูลสำเร็จ (Restore Success)'
                  : 'กู้คืนข้อมูลล้มเหลว (Restore Failed)',
              type: success ? 'success' : 'error',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Restore Error: $e');
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('ความถี่การสำรองข้อมูล (Frequency)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('ปัจจุบัน: ${_getIntervalLabel(_interval)}'),
          trailing: DropdownButton<String>(
            value: _interval,
            items: const [
              DropdownMenuItem(
                  value: 'NONE', child: Text('ปิดใช้งาน (Disable)')),
              DropdownMenuItem(value: '6H', child: Text('ทุก 6 ชั่วโมง')),
              DropdownMenuItem(value: 'DAILY', child: Text('ทุกวัน (24 ชม.)')),
              DropdownMenuItem(value: 'WEEKLY', child: Text('ทุกสัปดาห์')),
              DropdownMenuItem(value: 'MONTHLY', child: Text('ทุกเดือน')),
            ],
            onChanged: (v) => _saveSetting('backup_interval_type', v!),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('ตำแหน่งจัดเก็บ (Destination)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              _destination == 'LOCAL' ? 'เก็บในเครื่องนี้' : 'Google Drive'),
          trailing: ToggleButtons(
            isSelected: [_destination == 'LOCAL', _destination == 'DRIVE'],
            onPressed: (index) async {
              await _saveSetting(
                  'backup_destination', index == 0 ? 'LOCAL' : 'DRIVE');
              if (index == 1) {
                // Trigger Auth if needed
                final ok = await GoogleDriveService().authenticate();
                if (!context.mounted) return;

                if (!ok) {
                  AlertService.show(
                    context: context,
                    message: 'Google Sign-In Failed',
                    type: 'error',
                  );
                  _saveSetting('backup_destination', 'LOCAL');
                }
              }
            },
            children: const [
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Local')),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Drive')),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          leading: _isBackingUp
              ? const CircularProgressIndicator()
              : const Icon(Icons.backup, color: Colors.green),
          title: const Text('สำรองข้อมูลทันที (Backup Now)'),
          subtitle: const Text('กดเพื่อสั่ง Backup เดี๋ยวนี้'),
          onTap: _isBackingUp ? null : _manualBackup,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.restore, color: Colors.orange),
          title: const Text('กู้คืนข้อมูล (Restore Data)'),
          subtitle: const Text('นำเข้าไฟล์ Backup (.JSON) เพื่อกู้คืน'),
          onTap: _isBackingUp ? null : _restoreData,
        ),
      ],
    );
  }

  String _getIntervalLabel(String v) {
    switch (v) {
      case '6H':
        return 'ทุก 6 ชั่วโมง';
      case 'DAILY':
        return 'ทุกวัน';
      case 'WEEKLY':
        return 'ทุกสัปดาห์';
      case 'MONTHLY':
        return 'ทุกเดือน';
      default:
        return 'ปิดใช้งาน';
    }
  }
}

class DatabaseSettingsWidget extends StatefulWidget {
  const DatabaseSettingsWidget({super.key});

  @override
  State<DatabaseSettingsWidget> createState() => _DatabaseSettingsWidgetState();
}

class _DatabaseSettingsWidgetState extends State<DatabaseSettingsWidget> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dbCtrl = TextEditingController();

  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostCtrl.text = prefs.getString('db_host') ?? '127.0.0.1';
      _portCtrl.text = (prefs.getInt('db_port') ?? 3306).toString();
      _userCtrl.text = prefs.getString('db_user') ?? 'root';
      _passCtrl.text = prefs.getString('db_pass') ?? '';
      _dbCtrl.text = prefs.getString('db_name') ?? 'sorborikan';
    });
  }

  Future<void> _testAndSave() async {
    setState(() => _isTesting = true);
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 3306;
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final db = _dbCtrl.text.trim();

    try {
      final errorMsg = await MySQLService().testConnection(
        host: host,
        port: port,
        user: user,
        pass: pass,
        db: db,
      );

      if (!mounted) return;

      if (errorMsg == null) {
        await MySQLService().saveConfig(
          host: host,
          port: port,
          user: user,
          pass: pass,
          db: db,
        );
        if (!mounted) return;
        AlertService.show(
          context: context,
          message: 'เชื่อมต่อสำเร็จและบันทึกค่าแล้ว (Success)',
          type: 'success',
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Connection Failed',
                  style: TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                child: SelectableText(
                  'Error Details:\n$errorMsg',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CustomTextField(
            controller: _hostCtrl,
            label: 'MySQL Host',
            prefixIcon: Icons.dns,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: _userCtrl,
                  label: 'Username',
                  prefixIcon: Icons.person,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: CustomTextField(
                  controller: _portCtrl,
                  keyboardType: TextInputType.number,
                  label: 'Port',
                  prefixIcon: Icons.settings_ethernet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _passCtrl,
            label: 'Password',
            obscureText: true,
            prefixIcon: Icons.lock,
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _dbCtrl,
            label: 'Database Name',
            prefixIcon: Icons.storage,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              onPressed: _isTesting ? null : _testAndSave,
              label: _isTesting ? 'กำลังตรวจสอบ...' : 'ทดสอบและบันทึก',
              icon: Icons.save,
              isLoading: _isTesting,
            ),
          ),
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
