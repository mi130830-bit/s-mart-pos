import 'package:flutter/material.dart';

class AdminSetupStep extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final bool isLoading;
  final VoidCallback onCreateAdmin;

  const AdminSetupStep({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.passwordConfirmController,
    required this.isLoading,
    required this.onCreateAdmin,
  });

  @override
  Widget build(BuildContext context) {
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
          controller: usernameController,
          decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordConfirmController,
          decoration:
              const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onCreateAdmin,
          icon: const Icon(Icons.person_add),
          label: const Text('สร้าง Admin และเริ่มใช้งาน'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
      ],
    );
  }
}
