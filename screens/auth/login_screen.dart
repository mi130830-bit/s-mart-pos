import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../settings/initial_setup_screen.dart';
import '../pos/pos_state_manager.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final creds = await auth.loadSavedCredentials();
    if (creds['username']!.isNotEmpty) {
      setState(() {
        _usernameCtrl.text = creds['username']!;
        _passwordCtrl.text = creds['password']!;
        _rememberMe = true;
      });
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // Pass rememberMe flag to login function
      final success = await auth.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        rememberMe: _rememberMe,
      );
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final posState = Provider.of<PosStateManager>(context);
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo.shade800, Colors.indigo.shade400],
              ),
            ),
            child: Center(
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.store, size: 80, color: Colors.indigo),
                        const SizedBox(height: 20),
                        const Text(
                          'S_MartPOS', // ✅ Updated Name
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5), // Added spacing
                        Text(
                          'เข้าสู่ระบบ ${posState.shopName}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'เข้าสู่ระบบเพื่อใช้งาน',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 30),
                        CustomTextField(
                          controller: _usernameCtrl,
                          label: 'ชื่อผู้ใช้',
                          prefixIcon: Icons.person,
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _passwordCtrl,
                          label: 'รหัสผ่าน',
                          obscureText: _isObscure,
                          prefixIcon: Icons.lock,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _isObscure = !_isObscure),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        // ✅ Remember Me Checkbox
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                              activeColor: Colors.indigo,
                            ),
                            const Text('จดจำรหัสผ่าน'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: CustomButton(
                            label: 'เข้าสู่ระบบ',
                            onPressed: auth.isLoading ? null : _handleLogin,
                            isLoading: auth.isLoading,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ⚙️ Database Setup Button
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InitialSetupScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.settings,
                            size: 16,
                            color: Colors.grey,
                          ),
                          label: const Text(
                            'ตั้งค่าฐานข้อมูล (Database Setup)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
