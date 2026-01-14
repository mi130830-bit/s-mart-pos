import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';
import '../../models/user.dart' as model;
import '../../services/alert_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

// --- User Model (Updated with Permissions) ---
// Local User model is no longer needed since we use models/user.dart

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserRepository _userRepo = UserRepository();
  List<model.User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await _userRepo.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  // ฟังก์ชันแสดง Dialog เพิ่ม/แก้ไข ผู้ใช้
  void _showUserDialog({model.User? user}) {
    final isEditing = user != null;

    // Controllers
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final nameCtrl = TextEditingController(text: user?.displayName ?? '');
    final passwordCtrl = TextEditingController();

    String selectedRole = user?.role ?? 'CASHIER';
    // ✅ Ensure Active is checked by default for new users
    bool isActive = user != null ? user.isActive : true;

    // ✅ State สำหรับ Permission
    Map<String, bool> permissions = {};
    bool isPermLoading = true;

    // Load Permissions if editing
    if (isEditing) {
      _userRepo.getPermissions(user.id).then((perms) {
        if (mounted) {
          setState(() {
            permissions = perms;
            isPermLoading = false;
          });
        }
      });
    } else {
      isPermLoading = false;
      // Default perms for new user (Standard Cashier Profile)
      permissions = {
        'sale': true,
        'open_drawer': true,
        'void_item': true, // ลบรายการสินค้า (จำเป็นตอนคีย์ผิด)
        'manage_customer': true, // จัดการลูกค้า/สมาชิก
        'view_sales_history': true, // ดูประวัติเพื่อพิมพ์ใบเสร็จซ้ำ
        'print_barcode': true, // พิมพ์บาร์โค้ด (เผื่อติดสินค้า)
        'view_cost': false,
        'view_profit': false,
      };
    }

    bool isPasswordVisible = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setState) {
          // Auto-check permissions if role is ADMIN
          // if (selectedRole == 'ADMIN') {
          // Admin should always have access, but let's keep it toggleable or force it based on logic
          // canViewCost = true;
          // canViewProfit = true;
          // }

          return AlertDialog(
            title: Text(isEditing ? 'แก้ไขผู้ใช้งาน' : 'เพิ่มผู้ใช้งานใหม่'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450, // ขยายกว้างขึ้นนิดหน่อย
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 1. ข้อมูลพื้นฐาน ---
                    CustomTextField(
                      controller: usernameCtrl,
                      label: 'ชื่อผู้ใช้ (Username)',
                      prefixIcon: Icons.person,
                      readOnly: isEditing,
                    ),
                    const SizedBox(height: 15),
                    CustomTextField(
                      controller: nameCtrl,
                      label: 'ชื่อ-นามสกุล (Display Name)',
                      prefixIcon: Icons.badge,
                    ),
                    const SizedBox(height: 15),

                    if (!isEditing)
                      CustomTextField(
                        controller: passwordCtrl,
                        obscureText: !isPasswordVisible,
                        label: 'รหัสผ่าน (Password)',
                        prefixIcon: Icons.key,
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    if (!isEditing) const SizedBox(height: 15),

                    // --- 2. บทบาทและสถานะ ---
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ✅ แก้ไข: ใช้ initialValue แทน value (ตามแจ้งเตือน Deprecated)
                            // และใส่ Key เพื่อให้ Rebuild ได้เมื่อค่าเปลี่ยนถ้าจำเป็น
                            key: ValueKey(selectedRole),
                            isExpanded: true,
                            initialValue: selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'บทบาท (Role)',
                              prefixIcon: Icon(Icons.admin_panel_settings),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ADMIN',
                                child: Text('Admin (ผู้ดูแล)'),
                              ),
                              DropdownMenuItem(
                                value: 'CASHIER',
                                child: Text('Cashier (พนักงาน)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedRole = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Active'),
                            value: isActive,
                            // ✅ แก้ไข: ใส่ปีกกา {} ให้ if/else และลบ ! ที่ไม่จำเป็น
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => isActive = val);
                              }
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'สิทธิ์การเข้าถึง (Detailed Permissions)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (isPermLoading)
                      const CircularProgressIndicator()
                    else
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _buildPermToggle(
                              'sale', 'ขายสินค้า', permissions, setState),
                          _buildPermToggle('void_item', 'ลบรายการ (Item)',
                              permissions, setState),
                          _buildPermToggle(
                              'void_bill', 'ยกเลิกบิล', permissions, setState),
                          _buildPermToggle(
                              'view_cost', 'ดูต้นทุน', permissions, setState),
                          _buildPermToggle('view_profit', 'ดูกำไร/ยอด',
                              permissions, setState),
                          _buildPermToggle('manage_product', 'จัดการสินค้า',
                              permissions, setState),
                          _buildPermToggle('manage_stock', 'คลังสินค้า',
                              permissions, setState),
                          _buildPermToggle('manage_user', 'จัดการพนักงาน',
                              permissions, setState),
                          _buildPermToggle('manage_settings', 'ตั้งค่าระบบ',
                              permissions, setState),
                          _buildPermToggle('pos_discount', 'ทำส่วนลด',
                              permissions, setState),
                          _buildPermToggle('open_drawer', 'เปิดลิ้นชัก',
                              permissions, setState),
                          _buildPermToggle('create_po', 'สร้างใบสั่งซื้อ',
                              permissions, setState),
                          _buildPermToggle('receive_stock', 'รับเข้าสต็อก',
                              permissions, setState),
                          _buildPermToggle('return_stock', 'รับคืนสินค้า',
                              permissions, setState),
                          _buildPermToggle('adjust_stock', 'ปรับสต็อก',
                              permissions, setState),
                          _buildPermToggle('view_stock_card', 'Stock Card',
                              permissions, setState),
                          _buildPermToggle('import_product', 'นำเข้าสินค้า',
                              permissions, setState),
                          _buildPermToggle('print_barcode', 'พิมพ์บาร์โค้ด',
                              permissions, setState),
                          _buildPermToggle('manage_customer', 'รายชื่อลูกค้า',
                              permissions, setState),
                          _buildPermToggle('customer_debt', 'ลูกหนี้/เครดิต',
                              permissions, setState),
                          _buildPermToggle('billing_note', 'ใบวางบิล',
                              permissions, setState),
                          _buildPermToggle('import_customer', 'นำเข้าลูกค้า',
                              permissions, setState),
                          _buildPermToggle('audit_log', 'ดู Log ประวัติ',
                              permissions, setState),
                          _buildPermToggle('view_dashboard_overview',
                              'Dash: ภาพรวม', permissions, setState),
                          _buildPermToggle('view_bestseller', 'Dash: ขายดี',
                              permissions, setState),
                          _buildPermToggle('view_payment_report',
                              'Dash: การเงิน', permissions, setState),
                          _buildPermToggle('view_ai_analysis', 'Dash: AI',
                              permissions, setState),
                          _buildPermToggle('view_sales_history',
                              'ดูประวัติขาย/ใบเสร็จ', permissions, setState),
                          _buildPermToggle(
                              'manage_master_data',
                              'จัดการข้อมูลหลัก (Master Data)',
                              permissions,
                              setState),

                          // --- New Granular Settings Permissions ---
                          _buildPermToggle('access_settings_menu',
                              'เข้าเมนูตั้งค่า', permissions, setState),
                          _buildPermToggle('settings_connection',
                              'ตั้งค่า: การเชื่อมต่อ', permissions, setState),
                          _buildPermToggle('settings_shop_info',
                              'ตั้งค่า: ร้านค้า', permissions, setState),
                          _buildPermToggle('settings_payment',
                              'ตั้งค่า: การเงิน', permissions, setState),
                          _buildPermToggle('settings_printer',
                              'ตั้งค่า: เครื่องพิมพ์', permissions, setState),
                          _buildPermToggle('settings_general',
                              'ตั้งค่า: ทั่วไป', permissions, setState),
                          _buildPermToggle('settings_display',
                              'ตั้งค่า: หน้าจอ', permissions, setState),
                          _buildPermToggle('settings_system', 'ตั้งค่า: ระบบ',
                              permissions, setState),
                          _buildPermToggle('settings_scanner',
                              'ตั้งค่า: บาร์โค้ด', permissions, setState),
                          _buildPermToggle('settings_expenses',
                              'ตั้งค่า: ค่าใช้จ่าย', permissions, setState),
                          _buildPermToggle('settings_ai', 'ตั้งค่า: AI',
                              permissions, setState),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              CustomButton(
                label: 'ยกเลิก',
                type: ButtonType.secondary,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
              CustomButton(
                label: 'บันทึก',
                onPressed: () async {
                  if (usernameCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                    AlertService.show(
                      context: dialogCtx, // Use dialog context for this warning
                      message: 'กรุณากรอกข้อมูลให้ครบถ้วน',
                      type: 'error',
                    );
                    return;
                  }

                  final newUser = model.User(
                    id: user?.id ?? 0,
                    username: usernameCtrl.text,
                    displayName: nameCtrl.text,
                    role: selectedRole,
                    passwordHash: passwordCtrl.text,
                    isActive: isActive,
                    canViewCostPrice: permissions['view_cost'] ?? false,
                    canViewProfit: permissions['view_profit'] ?? false,
                  );

                  // Capture navigator for popping
                  final navigator = Navigator.of(dialogCtx);
                  bool success = false;

                  if (isEditing) {
                    success = await _userRepo.updateUser(newUser);
                  } else {
                    success = await _userRepo.createUser(newUser);
                  }

                  if (success && mounted) {
                    // Save granular permissions if we have a valid ID
                    int targetId = newUser.id;
                    if (!isEditing) {
                      final u =
                          await _userRepo.getUserByUsername(newUser.username);
                      if (u != null) targetId = u.id;
                    }

                    if (targetId > 0) {
                      await _userRepo.setPermissions(targetId, permissions);
                    }

                    if (mounted) {
                      navigator.pop();
                      _loadData();
                      AlertService.show(
                        context: context, // Use State context (this.context)
                        message: 'บันทึกข้อมูลเรียบร้อย',
                        type: 'success',
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(model.User user) {
    ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content:
          'ต้องการลบผู้ใช้ "${user.username}" หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
      isDestructive: true,
      onConfirm: () async {
        final ok = await _userRepo.deleteUser(user.id);

        if (ok && mounted) {
          _loadData();
          AlertService.show(
            context: context,
            message: 'ลบผู้ใช้งานเรียบร้อย',
            type: 'success',
          );
        }
      },
    );
  }

  void _changePassword(model.User user) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    bool isPassVisible = false;
    bool isConfirmVisible = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text('เปลี่ยนรหัสผ่าน: ${user.username}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: passCtrl,
                  obscureText: !isPassVisible,
                  label: 'รหัสผ่านใหม่',
                  prefixIcon: Icons.lock,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPassVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => isPassVisible = !isPassVisible),
                  ),
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: confirmCtrl,
                  obscureText: !isConfirmVisible,
                  label: 'ยืนยันรหัสผ่านใหม่',
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isConfirmVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => isConfirmVisible = !isConfirmVisible),
                  ),
                ),
              ],
            ),
            actions: [
              CustomButton(
                label: 'ยกเลิก',
                type: ButtonType.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
              CustomButton(
                label: 'บันทึก',
                onPressed: () async {
                  if (passCtrl.text.isEmpty) return;

                  if (passCtrl.text != confirmCtrl.text) {
                    AlertService.show(
                      context:
                          ctx, // Alert on dialog is okay, or use state context
                      message: 'รหัสผ่านไม่ตรงกัน',
                      type: 'error',
                    );
                    return;
                  }

                  final navigator = Navigator.of(ctx);
                  final ok =
                      await _userRepo.changePassword(user.id, passCtrl.text);

                  if (ok && mounted) {
                    navigator.pop();
                    AlertService.show(
                      context: context, // Use State context
                      message: 'เปลี่ยนรหัสผ่านเรียบร้อย',
                      type: 'success',
                    );
                  } else if (mounted) {
                    AlertService.show(
                      context: context,
                      message: 'เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน',
                      type: 'error',
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการผู้ใช้งาน (User Management)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('เพิ่มผู้ใช้งาน'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้งาน'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final user = _users[i];
                    final isAdmin = user.role == 'ADMIN';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                          decoration:
                              user.isActive ? null : TextDecoration.lineThrough,
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
                              // Badge: Role
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? Colors.indigo.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isAdmin
                                        ? Colors.indigo.shade100
                                        : Colors.green.shade100,
                                  ),
                                ),
                                child: Text(
                                  user.role,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isAdmin ? Colors.indigo : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Badge: View Cost
                              if (user.canViewCostPrice)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: const Text(
                                    'เห็นทุน',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ),
                              // Badge: View Profit
                              if (user.canViewProfit)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.purple.shade200,
                                    ),
                                  ),
                                  child: const Text(
                                    'เห็นกำไร',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple,
                                    ),
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
                            icon:
                                const Icon(Icons.vpn_key, color: Colors.orange),
                            tooltip: 'เปลี่ยนรหัสผ่าน',
                            onPressed: () => _changePassword(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'แก้ไขข้อมูล',
                            onPressed: () => _showUserDialog(user: user),
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
                ),
    );
  }

  Widget _buildPermToggle(
      String key, String label, Map<String, bool> perms, StateSetter setState) {
    bool isAllowed = perms[key] ?? false;
    return GestureDetector(
      onTap: () {
        setState(() {
          perms[key] = !isAllowed;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isAllowed ? Colors.blue.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: isAllowed ? Colors.blue.shade900 : Colors.grey.shade400),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAllowed ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: isAllowed ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11, // Reduced font size slightly
                  color: isAllowed ? Colors.white : Colors.black87,
                  fontWeight: isAllowed ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
