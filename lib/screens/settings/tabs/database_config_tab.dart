import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../services/mysql_service.dart';

class DatabaseConfigTab extends StatefulWidget {
  const DatabaseConfigTab({super.key});

  @override
  State<DatabaseConfigTab> createState() => _DatabaseConfigTabState();
}

class _DatabaseConfigTabState extends State<DatabaseConfigTab> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dbCtrl = TextEditingController();
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadDBRun();
  }

  Future<void> _loadDBRun() async {
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
        if (mounted) {
          AlertService.show(
            context: context,
            message: 'เชื่อมต่อสำเร็จและบันทึกค่าแล้ว',
            type: 'success',
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Connection Failed',
                  style: TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                  child: SelectableText('Error: $errorMsg')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK')),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'การตั้งค่าฐานข้อมูล (Database Connection)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Text(
          'โปรดระมัดระวัง: การเปลี่ยนค่ามั่วๆ อาจทำให้ระบบใช้งานไม่ได้',
          style: TextStyle(color: Colors.red, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
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
          ),
        ),
      ],
    );
  }
}
