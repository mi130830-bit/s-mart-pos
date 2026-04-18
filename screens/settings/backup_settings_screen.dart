import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../services/backup/google_drive_service.dart';
import '../../services/system/backup_service.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../services/mysql_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูล (Database & Backup)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'สำรอง & กู้คืน (Backup)'),
            Tab(text: 'ตั้งค่าฐานข้อมูล (DB Config)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BackupTab(),
          DatabaseConfigTab(),
        ],
      ),
    );
  }
}

class BackupTab extends StatefulWidget {
  const BackupTab({super.key});

  @override
  State<BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<BackupTab> {
  final _driveService = GoogleDriveService();
  final _backupService = BackupService();

  String _interval = 'NONE';
  String _destination = 'LOCAL';
  bool _isLoading = false;
  String? _statusMsg;

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

  // --- Actions ---

  Future<void> _performManualBackup() async {
    setState(() {
      _isLoading = true;
      _statusMsg = 'กำลังสำรองข้อมูล...';
    });

    try {
      final file = await _backupService.createBackup();
      if (file == null) throw Exception('สร้างไฟล์ Backup ล้มเหลว');

      bool uploaded = false;

      if (_destination == 'DRIVE') {
        if (await _driveService.authenticate()) {
          final id = await _driveService.uploadFile(
              file, 'Manual Backup via Settings');
          uploaded = id != null;
        } else {
          _statusMsg = 'Google Drive ยังไม่ได้เชื่อมต่อ (บันทึกลงเครื่องแทน)';
        }
      }

      if (mounted) {
        setState(() {
          if (_destination == 'DRIVE') {
            _statusMsg = uploaded
                ? '✅ สำรองข้อมูล (Drive) สำเร็จ \n(ไฟล์: ${file.path.split(Platform.pathSeparator).last})'
                : '⚠️ อัปโหลดไม่สำเร็จ (บันทึกในเครื่องแทน)';
          } else {
            _statusMsg =
                '✅ สำรองข้อมูล (Local) สำเร็จ \n(ไฟล์อยู่ที่: ${file.path})';
          }
        });

        AlertService.show(
          context: context,
          message: _statusMsg ?? 'เสร็จสิ้น',
          type: uploaded || _destination == 'LOCAL' ? 'success' : 'warning',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMsg = '❌ เกิดข้อผิดพลาด: $e');
        AlertService.show(
            context: context, message: 'Error: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreData() async {
    // Show Action Sheet (Local or Drive)
    if (_destination == 'DRIVE') {
      final success = await _driveService.authenticate();
      if (!mounted) return;
      if (success) {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.blue),
                title: const Text('Restore from Google Drive'),
                subtitle: const Text('เลือกไฟล์จาก Cloud'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDriveFilePicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.brown),
                title: const Text('Restore from Local File'),
                subtitle: const Text('เลือกไฟล์จากเครื่อง'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLocalAndRestore();
                },
              ),
            ],
          ),
        );
        return;
      }
    }

    // Direct Local if not connected or auth failed
    _pickLocalAndRestore();
  }

  Future<void> _pickLocalAndRestore() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (!mounted) return;
        _confirmAndRestore(file);
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'Error: $e', type: 'error');
      }
    }
  }

  Future<void> _showDriveFilePicker() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final files = await _driveService.listBackups();
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (files.isEmpty) {
      AlertService.show(
          context: context,
          message: 'ไม่พบไฟล์ Backup ใน Google Drive',
          type: 'warning');
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เลือกไฟล์ Backup'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, index) {
              final f = files[index];
              final sizeMb = (double.parse(f.size ?? '0') / 1024 / 1024)
                  .toStringAsFixed(2);
              final date =
                  f.createdTime?.toLocal().toString().split('.')[0] ?? '-';

              return ListTile(
                leading: const Icon(Icons.description, color: Colors.blueGrey),
                title: Text(f.name ?? 'Unknown'),
                subtitle: Text('Date: $date | Size: $sizeMb MB'),
                onTap: () {
                  Navigator.pop(ctx); // Close List Dialog
                  _downloadAndRestore(f.id!, f.name!);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        ],
      ),
    );
  }

  Future<void> _downloadAndRestore(String id, String name) async {
    setState(() {
      _isLoading = true;
      _statusMsg = 'กำลังดาวน์โหลด $name ...';
    });

    final file = await _driveService.downloadFile(id, name);

    if (file != null) {
      _confirmAndRestore(file); // This will handle loading state inside
    } else {
      setState(() {
        _isLoading = false;
        _statusMsg = 'ดาวน์โหลดล้มเหลว';
      });
      if (mounted) {
        AlertService.show(
            context: context, message: 'Download Failed', type: 'error');
      }
    }
  }

  Future<void> _confirmAndRestore(File file) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการกู้คืนข้อมูล?',
      content:
          'ข้อมูลปัจจุบันทั้งหมดจะถูกลบและแทนที่ด้วยข้อมูลจาก:\n${file.path.split(Platform.pathSeparator).last}\n\nแน่ใจหรือไม่?',
      isDestructive: true,
      confirmText: 'ยืนยันกู้คืน',
    );

    if (confirm == true && mounted) {
      setState(() {
        _isLoading = true;
        _statusMsg = 'กำลังกู้คืนข้อมูล...';
      });

      final success = await _backupService.restoreBackup(file);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMsg =
              success ? '✅ กู้คืนข้อมูลสำเร็จ' : '❌ กู้คืนข้อมูลล้มเหลว';
        });
        AlertService.show(
          context: context,
          message: success ? 'กู้คืนข้อมูลสำเร็จ' : 'กู้คืนข้อมูลล้มเหลว',
          type: success ? 'success' : 'error',
        );
      }
    } else {
      // Cancelled
      setState(() => _isLoading = false);
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLoading = true);
    final success = await _driveService.authenticate();
    setState(() {
      _isLoading = false;
      if (success) _statusMsg = '✅ เชื่อมต่อ Google แล้ว';
    });
    if (success) {
      _saveSetting('backup_destination', 'DRIVE');
    }
  }

  Future<void> _logoutGoogle() async {
    await _driveService.logout();
    setState(() => _statusMsg = 'ตัดการเชื่อมต่อแล้ว');
    _saveSetting('backup_destination', 'LOCAL');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Google Drive Connection',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.cloud_circle,
                        size: 40, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('สถานะการเชื่อมต่อ:'),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _linkGoogle,
                            icon: const Icon(Icons.link),
                            label: const Text('เชื่อมต่อ (Connect)'),
                            style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      tooltip: 'ตัดการเชื่อมต่อ',
                      onPressed: _isLoading ? null : _logoutGoogle,
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_statusMsg != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_statusMsg!,
                  style: const TextStyle(color: Colors.black87)),
            ),
          ),
        const SizedBox(height: 20),
        const Text('ตั้งค่าอัตโนมัติ (Schedule)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('ความถี่การสำรองข้อมูล'),
                subtitle: Text('ปัจจุบัน: ${_getIntervalLabel(_interval)}'),
                trailing: DropdownButton<String>(
                  value: _interval,
                  items: const [
                    DropdownMenuItem(
                        value: 'NONE', child: Text('ปิดใช้งาน (Disable)')),
                    DropdownMenuItem(value: '30M', child: Text('ทุก 30 นาที')),
                    DropdownMenuItem(value: '1H', child: Text('ทุก 1 ชั่วโมง')),
                    DropdownMenuItem(value: '6H', child: Text('ทุก 6 ชั่วโมง')),
                    DropdownMenuItem(
                        value: 'DAILY', child: Text('ทุกวัน (24 ชม.)')),
                    DropdownMenuItem(
                        value: 'WEEKLY', child: Text('ทุกสัปดาห์')),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('ทุกเดือน')),
                  ],
                  onChanged: (v) => _saveSetting('backup_interval_type', v!),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('ปลายทางจัดเก็บ (Destination)'),
                subtitle: Text(_destination == 'LOCAL'
                    ? 'ในเครื่อง (Local)'
                    : 'Google Drive'),
                trailing: ToggleButtons(
                  isSelected: [
                    _destination == 'LOCAL',
                    _destination == 'DRIVE'
                  ],
                  onPressed: (index) async {
                    final newDest = index == 0 ? 'LOCAL' : 'DRIVE';
                    if (newDest == 'DRIVE') {
                      final ok = await _driveService.authenticate();
                      if (!context.mounted) return;
                      if (!ok) {
                        AlertService.show(
                            context: context,
                            message: 'กรุณาเชื่อมต่อ Google Account ก่อน',
                            type: 'warning');
                        return;
                      }
                    }
                    _saveSetting('backup_destination', newDest);
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('ดำเนินการ (Actions)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt, color: Colors.green),
                title: const Text('สำรองข้อมูลทันที (Backup Now)'),
                subtitle: const Text('กดเพื่อเริ่ม Backup เดี๋ยวนี้'),
                onTap: _isLoading ? null : _performManualBackup,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.orange),
                title: const Text('กู้คืนข้อมูล (Restore Data)'),
                subtitle: const Text('นำเข้าไฟล์ .JSON เพื่อกู้คืน'),
                onTap: _isLoading ? null : _restoreData,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getIntervalLabel(String v) {
    switch (v) {
      case '30M':
        return 'ทุก 30 นาที';
      case '1H':
        return 'ทุก 1 ชั่วโมง';
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
