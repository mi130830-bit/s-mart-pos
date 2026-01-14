import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/mysql_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class DatabaseConfigScreen extends StatefulWidget {
  const DatabaseConfigScreen({super.key});

  @override
  State<DatabaseConfigScreen> createState() => _DatabaseConfigScreenState();
}

class _DatabaseConfigScreenState extends State<DatabaseConfigScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dbCtrl = TextEditingController();

  String _selectedMode = 'standalone'; // standalone, client, trial
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMode = prefs.getString('db_mode') ?? 'standalone';
      _hostCtrl.text = prefs.getString('db_host') ?? '127.0.0.1';
      _portCtrl.text = (prefs.get('db_port') ?? '3306').toString();
      _userCtrl.text = prefs.getString('db_user') ?? 'admin';
      _passCtrl.text = prefs.getString('db_pass') ?? '1234';
      _dbCtrl.text = prefs.getString('db_name') ?? 'sorborikan';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('db_mode', _selectedMode);
    await prefs.setString('db_host', _hostCtrl.text.trim());
    await prefs.setInt('db_port', int.tryParse(_portCtrl.text) ?? 3306);
    await prefs.setString('db_user', _userCtrl.text.trim());
    await prefs.setString('db_pass', _passCtrl.text);
    await prefs.setString('db_name', _dbCtrl.text.trim());
  }

  void _applyMode(String mode) {
    setState(() {
      _selectedMode = mode;
      if (mode == 'standalone') {
        _hostCtrl.text = '127.0.0.1';
        _portCtrl.text = '3306';
        _userCtrl.text = 'admin';
        _passCtrl.text = '1234';
        _dbCtrl.text = 'sorborikan';
      } else if (mode == 'trial') {
        _hostCtrl.text = '127.0.0.1';
        _portCtrl.text = '3306';
        _userCtrl.text = 'admin';
        _passCtrl.text = '1234';
        _dbCtrl.text = 'sorborikan_trial';
      }
      // client mode leaves fields for user to fill
    });
  }

  Future<void> _testAndSave() async {
    setState(() => _isTesting = true);
    final service = MySQLService();
    // ✅ รับค่าเป็น String? (null = สำเร็จ)
    final errorMsg = await service.testConnection(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? 3306,
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text,
      db: _dbCtrl.text.trim(),
    );

    setState(() => _isTesting = false);

    if (errorMsg == null) {
      // ✅ Success
      await _saveSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('เชื่อมต่อสำเร็จและบันทึกข้อมูลแล้ว'),
              backgroundColor: Colors.green),
        );
        // ขอให้ Restart App
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('บันทึกสำเร็จ'),
              content: const Text(
                  'กรุณาปิดและเปิดโปรแกรมใหม่เพื่อให้การตั้งค่ามีผล'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ตกลง'),
                ),
              ],
            ),
          ).then((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } else {
      // ❌ Failed with Reason
      if (mounted) {
        // Show specific error in Dialog for better readability
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('เชื่อมต่อไม่สำเร็จ (Connection Failed)',
                style: TextStyle(color: Colors.red)),
            content: SingleChildScrollView(
              child: SelectableText(
                'เกิดข้อผิดพลาด:\n$errorMsg\n\nคำแนะนำ:\n1. ตรวจสอบ IP Address เครื่องแม่\n2. ตรวจสอบ Firewall (Port 3306)\n3. ตรวจสอบ Username/Password',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('ตั้งค่าฐานข้อมูล (Database Config)',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เลือกโหมดการใช้งาน',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildModeCard(
                    'standalone', 'เครื่องเดียว', Icons.computer, Colors.blue),
                const SizedBox(width: 12),
                _buildModeCard(
                    'client', 'ดึงจากเครื่องแม่', Icons.hub, Colors.orange),
                const SizedBox(width: 12),
                _buildModeCard(
                    'trial', 'ลองเล่น (Demo)', Icons.science, Colors.purple),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildTextField(_hostCtrl, 'MySQL Host',
                      'เช่น localhost หรือ 192.168.1.50'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child:
                              _buildTextField(_userCtrl, 'Username', 'admin')),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 1,
                          child: _buildTextField(_portCtrl, 'Port', '3306',
                              isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_passCtrl, 'Password', 'รหัสผ่าน',
                      isPassword: true),
                  const SizedBox(height: 16),
                  _buildTextField(_dbCtrl, 'Database Name', 'sorborikan'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      onPressed: _isTesting ? null : _testAndSave,
                      icon: _isTesting ? null : Icons.save,
                      label: _isTesting ? 'กำลังทดสอบ...' : 'ทดสอบและบันทึก',
                      type: ButtonType.primary,
                      backgroundColor: Colors.indigo.shade700,
                      isLoading: _isTesting,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(String mode, String label, IconData icon, Color color) {
    bool isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => _applyMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? color : Colors.grey.shade300, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint,
      {bool isNumber = false, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        CustomTextField(
          controller: ctrl,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          label: label,
          hint: hint,
        ),
      ],
    );
  }
}
