import 'package:flutter/material.dart';
import '../../models/user.dart' as model;
import '../../widgets/common/confirm_dialog.dart';
import '../../services/alert_service.dart';
import '../../controllers/user_management_controller.dart';
import 'widgets/user_form_dialog.dart';
import 'widgets/change_password_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  // ไม่ต้องใช้ _controller หรือ initState อีกต่อไปเพราะ Riverpod จะจัดการให้เมื่อถูกเรียกใช้
  
  void _confirmDelete(model.User user) {
    ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบผู้ใช้ "${user.username}" หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
      isDestructive: true,
      onConfirm: () async {
        final ok = await ref.read(userManagementProvider.notifier).deleteUser(user.id);
        if (ok && mounted) {
          AlertService.show(
            context: context,
            message: 'ลบผู้ใช้งานเรียบร้อย',
            type: 'success',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการผู้ใช้งาน (User Management)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => UserFormDialog.show(context),
        icon: const Icon(Icons.person_add),
        label: const Text('เพิ่มผู้ใช้งาน'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Builder(
        builder: (context) {
          final state = ref.watch(userManagementProvider);
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.users.isEmpty) {
            return const Center(child: Text('ไม่พบข้อมูลผู้ใช้งาน'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.users.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final user = state.users[i];
              final isAdmin = user.role == 'ADMIN';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: user.isActive
                      ? (isAdmin ? Colors.indigo : Colors.green)
                      : Colors.grey,
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: user.isActive ? null : TextDecoration.lineThrough,
                    color: user.isActive ? Colors.black : Colors.grey,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Username: ${user.username}'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAdmin ? Colors.indigo.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isAdmin ? Colors.indigo.shade100 : Colors.green.shade100,
                            ),
                          ),
                          child: Text(
                            user.role,
                            style: TextStyle(
                              fontSize: 10,
                              color: isAdmin ? Colors.indigo : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (user.canViewCostPrice)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Text(
                              'เห็นทุน',
                              style: TextStyle(fontSize: 10, color: Colors.deepOrange),
                            ),
                          ),
                        if (user.canViewProfit)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: const Text(
                              'เห็นกำไร',
                              style: TextStyle(fontSize: 10, color: Colors.purple),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.vpn_key, color: Colors.orange),
                      tooltip: 'เปลี่ยนรหัสผ่าน',
                      onPressed: () => ChangePasswordDialog.show(context, user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'แก้ไขข้อมูล',
                      onPressed: () => UserFormDialog.show(context, user: user),
                    ),
                    if (user.id != 1)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'ลบผู้ใช้งาน',
                        onPressed: () => _confirmDelete(user),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
