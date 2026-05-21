import 'package:flutter/material.dart';
import '../../services/mysql_service.dart';
import '../../services/settings_service.dart';
import '../../repositories/user_repository.dart';
import '../../models/user.dart';
import 'package:dbcrypt/dbcrypt.dart';
import '../../services/alert_service.dart';
import 'dart:io';
import 'widgets/db_config_step.dart';
import 'widgets/admin_setup_step.dart';

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
  final _machineNameController = TextEditingController();

  // Step 2: Admin Setup
  final _adminUserController = TextEditingController(text: 'admin');
  final _adminPassController = TextEditingController();
  final _adminPassConfirmController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isServer = true;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    _dbController.dispose();
    _machineNameController.dispose();
    _adminUserController.dispose();
    _adminPassController.dispose();
    _adminPassConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final config = await MySQLService().getConfig();
    if (config['host'] != null && mounted) {
      setState(() {
        _hostController.text = config['host']!;
        _portController.text = config['port'] ?? '3306';
        _userController.text = config['user'] ?? 'root';
        _passController.text = config['pass'] ?? '';
        _dbController.text = config['db'] ?? 'sorborikan';
        _machineNameController.text = config['machine_name'] ?? '';

        _isServer = _hostController.text == '127.0.0.1' ||
            _hostController.text == 'localhost';
      });
    }
  }

  void _handleServerModeChanged(bool value) {
    setState(() {
      _isServer = value;
      if (_isServer) {
        _hostController.text = '127.0.0.1';
      } else {
        if (_hostController.text == '127.0.0.1') {
          _hostController.text = '';
        }
      }
    });
  }

  Future<void> _testAndSaveConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      String originalHost = _hostController.text.trim();
      String testHost = originalHost;
      String resolvedApiHost = originalHost;

      if (testHost != 'localhost' &&
          testHost != '127.0.0.1' &&
          !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(testHost)) {
        try {
          final lookupHosts = [testHost];
          if (!testHost.contains('.')) lookupHosts.add('$testHost.local');

          bool resolved = false;
          for (var h in lookupHosts) {
            if (resolved) break;
            try {
              final result =
                  await InternetAddress.lookup(h).timeout(const Duration(seconds: 3));
              for (var addr in result) {
                if (addr.type == InternetAddressType.IPv4) {
                  testHost = addr.address;
                  resolvedApiHost = h;
                  resolved = true;
                  debugPrint('✅ [Setup] Auto-resolved $h to IPv4: $testHost');
                  break;
                }
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      final port = int.tryParse(_portController.text.trim()) ?? 3306;
      final user = _userController.text.trim();
      final pass = _passController.text;
      final db = _dbController.text.trim();

      final error = await MySQLService()
          .testConnection(host: testHost, port: port, user: user, pass: pass, db: db);

      if (error != null) {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'เชื่อมต่อไม่สำเร็จ: $error';
        });
      } else {
        await MySQLService().saveConfig(
          host: originalHost,
          port: port,
          user: user,
          pass: pass,
          db: db,
          machineName: _isServer ? _machineNameController.text.trim() : null,
        );

        try {
          final settings = SettingsService();
          String finalApiHost = resolvedApiHost;
          if (finalApiHost == '127.0.0.1') finalApiHost = 'localhost';
          final newApiUrl = 'http://$finalApiHost:8080/api/v1';
          await settings.set('api_url', newApiUrl);
          debugPrint('📡 [Setup] Auto-synced API URL to: $newApiUrl');
        } catch (e) {
          debugPrint('⚠️ [Setup] Failed to sync API URL: $e');
        }

        final userRepo = UserRepository();
        final users = await userRepo.getAllUsers();
        if (users.isEmpty) {
          await MySQLService().initUserPermissionTable();
          setState(() {
            _isSuccess = true;
            _statusMessage = 'เชื่อมต่อสำเร็จ!';
            _currentStep = 1;
          });
        } else {
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAdminUser() async {
    final user = _adminUserController.text.trim();
    final pass = _adminPassController.text;
    final confirm = _adminPassConfirmController.text;

    if (user.isEmpty || pass.isEmpty) {
      AlertService.show(context: context, message: 'กรุณากรอกข้อมูลให้ครบ', type: 'warning');
      return;
    }
    if (pass != confirm) {
      AlertService.show(context: context, message: 'รหัสผ่านไม่ตรงกัน', type: 'warning');
      return;
    }

    setState(() => _isLoading = true);

    try {
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

      final createdUsers = await repo.getAllUsers();
      final createdUser = createdUsers.firstWhere((u) => u.username == user);

      await repo.setPermissions(createdUser.id, {
        'sale': true, 'void_item': true, 'void_bill': true, 'view_cost': true,
        'view_profit': true, 'manage_product': true, 'manage_stock': true,
        'manage_user': true, 'manage_settings': true, 'pos_discount': true,
        'open_drawer': true, 'create_po': true, 'receive_stock': true,
        'audit_log': true, 'customer_debt': true, 'settings_shop_info': true,
        'settings_payment': true, 'settings_printer': true, 'settings_general': true,
        'settings_display': true, 'settings_system': true, 'settings_scanner': true,
        'settings_expenses': true, 'settings_ai': true,
      });

      if (mounted) {
        AlertService.show(context: context, message: 'สร้าง Admin เรียบร้อย!', type: 'success');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'Error: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  ? DbConfigStep(
                      formKey: _formKey,
                      hostController: _hostController,
                      portController: _portController,
                      userController: _userController,
                      passController: _passController,
                      dbController: _dbController,
                      machineNameController: _machineNameController,
                      isServer: _isServer,
                      isLoading: _isLoading,
                      statusMessage: _statusMessage,
                      isSuccess: _isSuccess,
                      onServerModeChanged: _handleServerModeChanged,
                      onTestAndSave: _testAndSaveConnection,
                    )
                  : AdminSetupStep(
                      usernameController: _adminUserController,
                      passwordController: _adminPassController,
                      passwordConfirmController: _adminPassConfirmController,
                      isLoading: _isLoading,
                      onCreateAdmin: _createAdminUser,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
