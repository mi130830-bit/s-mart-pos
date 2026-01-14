import 'package:flutter/material.dart';
import '../../services/mysql_service.dart';
import '../../repositories/user_repository.dart';
import '../../models/user.dart';
import 'package:dbcrypt/dbcrypt.dart';
// import '../auth/login_screen.dart'; // ✅ Removed as we use pop

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step 1: DB Config
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '3306');
  final _userController = TextEditingController(text: 'root');
  final _passController = TextEditingController();
  final _dbController = TextEditingController(text: 'sorborikan');

  // Step 2: Admin Setup
  final _adminUserController = TextEditingController(text: 'admin');
  final _adminPassController = TextEditingController();
  final _adminPassConfirmController = TextEditingController();

  int _currentStep = 0; // 0=DB, 1=Admin
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าเริ่มต้นใช้งาน (Initial Setup)'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _currentStep == 0
                  ? _buildDbConfigStep()
                  : _buildAdminSetupStep(),
            ),
          ),
        ),
      ),
    );
  }

  bool _isServer = true; // ✅ Default to Server (Machine 1)

  Widget _buildDbConfigStep() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('1. การตั้งค่าฐานข้อมูล (Database)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ✅ Machine Type Selector (RadioGroup)
          RadioGroup<bool>(
            groupValue: _isServer,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _isServer = v;
                if (_isServer) {
                  _hostController.text = '127.0.0.1';
                } else {
                  if (_hostController.text == '127.0.0.1') {
                    _hostController.text = '';
                  }
                }
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('เครื่องแม่ (Server)'),
                    subtitle: const Text('เครื่องนี้เก็บฐานข้อมูลไว้ที่ตัวเอง'),
                    leading: const Radio<bool>(value: true),
                    onTap: () {
                      setState(() {
                        _isServer = true;
                        _hostController.text = '127.0.0.1';
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('เครื่องลูก (Client)'),
                    subtitle: const Text('เชื่อมต่อกับเครื่องแม่ผ่าน Network'),
                    leading: const Radio<bool>(value: false),
                    onTap: () {
                      setState(() {
                        _isServer = false;
                        if (_hostController.text == '127.0.0.1') {
                          _hostController.text = '';
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 10),

          // Host Input
          TextFormField(
            controller: _hostController,
            enabled: !_isServer, // ✅ Readonly if Server
            decoration: InputDecoration(
              labelText:
                  _isServer ? 'Host IP (Local)' : 'Host IP / Machine Name',
              hintText: _isServer
                  ? '127.0.0.1'
                  : 'ตัวอย่าง: 192.168.1.100 หรือ COMPUTER-01',
              border: const OutlineInputBorder(),
              suffixIcon: _isServer
                  ? const Icon(Icons.lock_outline, color: Colors.grey)
                  : null,
            ),
            validator: (v) => v!.isEmpty ? 'ระบุ Host/IP' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _portController,
            decoration: const InputDecoration(
                labelText: 'Port', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (v) => v!.isEmpty ? 'ระบุ Port' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userController,
            decoration: const InputDecoration(
                labelText: 'DB Username', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'ระบุ Username' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passController,
            decoration: const InputDecoration(
                labelText: 'DB Password', border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dbController,
            decoration: const InputDecoration(
                labelText: 'Database Name', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'ระบุชื่อฐานข้อมูล' : null,
          ),
          const SizedBox(height: 20),
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
              child: Text(_statusMessage!,
                  style: TextStyle(
                      color: _isSuccess
                          ? Colors.green.shade900
                          : Colors.red.shade900)),
            ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _testAndSaveConnection,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('ทดสอบและบันทึกการตั้งค่า'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSetupStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('2. สร้างบัญชีผู้ดูแลระบบ (Admin)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('ระบบยังไม่มีผู้ใช้งาน กรุณาสร้าง Admin คนแรก',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(
          controller: _adminUserController,
          decoration: const InputDecoration(
              labelText: 'Username', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminPassController,
          decoration: const InputDecoration(
              labelText: 'Password', border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminPassConfirmController,
          decoration: const InputDecoration(
              labelText: 'Confirm Password', border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _createAdminUser,
          icon: const Icon(Icons.person_add),
          label: const Text('สร้าง Admin และเริ่มใช้งาน'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
      ],
    );
  }

  Future<void> _testAndSaveConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 3306;
      final user = _userController.text.trim();
      final pass = _passController.text;
      final db = _dbController.text.trim();

      // Test
      final error = await MySQLService().testConnection(
          host: host, port: port, user: user, pass: pass, db: db);

      if (error != null) {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'เชื่อมต่อไม่สำเร็จ: $error';
        });
      } else {
        // Save
        await MySQLService()
            .saveConfig(host: host, port: port, user: user, pass: pass, db: db);

        // Initial Tables
        // We need to re-connect effectively? saveConfig calls connect().

        // Check if we need Admin Setup
        final userRepo = UserRepository();
        // We can't call initializeDefaultAdmin because it has hardcoded logic.
        // Instead we check manually.
        final users = await userRepo.getAllUsers();
        if (users.isEmpty) {
          // Init tables if new DB
          await MySQLService().initUserPermissionTable();
          // (Other inits mainly happen in main or on demand, but good to init permission)

          setState(() {
            _isSuccess = true;
            _statusMessage = 'เชื่อมต่อสำเร็จ!';
            _currentStep = 1; // Go to Admin Setup
          });
        } else {
          // Users exist, done.
          // Users exist, done.
          if (mounted) {
            Navigator.pop(context); // ✅ Pop back if success
          }
        }
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAdminUser() async {
    final user = _adminUserController.text.trim();
    final pass = _adminPassController.text;
    final confirm = _adminPassConfirmController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบ')));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Hash Password
      final hashedPassword = DBCrypt().hashpw(pass, DBCrypt().gensalt());

      final newUser = User(
        id: 0,
        username: user,
        displayName: 'Administrator',
        role: 'ADMIN',
        passwordHash: hashedPassword,
        isActive: true,
        canViewCostPrice: true,
        canViewProfit: true,
      );

      final repo = UserRepository();
      await repo.createUser(newUser);

      // Get created ID (usually 1 if auto increment reset, or max id)
      // For simplicity, we query back by username
      final createdUsers = await repo.getAllUsers();
      final createdUser = createdUsers.firstWhere((u) => u.username == user);

      // Seed Permissions
      await repo.setPermissions(createdUser.id, {
        'sale': true,
        'void_item': true,
        'void_bill': true,
        'view_cost': true,
        'view_profit': true,
        'manage_product': true,
        'manage_stock': true,
        'manage_user': true,
        'manage_settings': true,
        'pos_discount': true,
        'open_drawer': true,
        'create_po': true,
        'receive_stock': true,
        'audit_log': true,
        'customer_debt': true,
        'settings_shop_info': true,
        'settings_payment': true,
        'settings_printer': true,
        'settings_general': true,
        'settings_display': true,
        'settings_system': true,
        'settings_scanner': true,
        'settings_expenses': true,
        'settings_ai': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('สร้าง Admin เรียบร้อย!')));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('สร้าง Admin เรียบร้อย!')));
          Navigator.pop(context); // ✅ Pop back to original LoginScreen
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
