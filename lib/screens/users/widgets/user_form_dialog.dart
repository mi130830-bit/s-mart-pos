import 'package:flutter/material.dart';
import '../../../models/user.dart' as model;
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../controllers/user_management_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserFormDialog extends ConsumerStatefulWidget {
  final model.User? user;

  const UserFormDialog({
    super.key,
    this.user,
  });

  static void show(BuildContext context, {model.User? user}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserFormDialog(user: user),
    );
  }

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  late TextEditingController _usernameCtrl;
  late TextEditingController _nameCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();

  late String _selectedRole;
  late bool _isActive;
  
  Map<String, bool> _permissions = {};
  bool _isPermLoading = true;
  bool _isPasswordVisible = false;
  bool _isSaving = false;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    _nameCtrl = TextEditingController(text: widget.user?.displayName ?? '');
    
    _selectedRole = widget.user?.role ?? 'CASHIER';
    _isActive = widget.user?.isActive ?? true;

    _loadPermissions();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    if (_isEditing) {
      final perms = await ref.read(userManagementProvider.notifier).loadPermissions(widget.user!.id);
      if (mounted) {
        setState(() {
          _permissions = perms;
          _isPermLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isPermLoading = false;
          _permissions = {
            'sale': true,
            'open_drawer': true,
            'void_item': true,
            'manage_customer': true,
            'view_sales_history': true,
            'print_barcode': true,
            'view_cost': false,
            'view_profit': false,
          };
        });
      }
    }
  }

  Widget _buildPermToggle(String key, String label) {
    bool isAllowed = _permissions[key] ?? false;
    return GestureDetector(
      onTap: () {
        setState(() {
          _permissions[key] = !isAllowed;
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
                  fontSize: 11,
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

  Future<void> _handleSave() async {
    if (_usernameCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอกข้อมูลให้ครบถ้วน',
        type: 'error',
      );
      return;
    }

    setState(() => _isSaving = true);

    final newUser = model.User(
      id: widget.user?.id ?? 0,
      username: _usernameCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      role: _selectedRole,
      passwordHash: '', // handled in controller for new users
      isActive: _isActive,
      canViewCostPrice: _permissions['view_cost'] ?? false,
      canViewProfit: _permissions['view_profit'] ?? false,
    );

    try {
      final success = await ref.read(userManagementProvider.notifier).saveUser(
        isEditing: _isEditing,
        newUser: newUser,
        permissions: _permissions,
        rawPassword: _passwordCtrl.text,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          AlertService.show(
            context: context,
            message: 'บันทึกข้อมูลเรียบร้อย',
            type: 'success',
          );
        } else {
          AlertService.show(
            context: context,
            message: 'เกิดข้อผิดพลาดในการบันทึกข้อมูล',
            type: 'error',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'แก้ไขผู้ใช้งาน' : 'เพิ่มผู้ใช้งานใหม่'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _usernameCtrl,
                label: 'ชื่อผู้ใช้ (Username)',
                prefixIcon: Icons.person,
                readOnly: _isEditing,
              ),
              const SizedBox(height: 15),
              CustomTextField(
                controller: _nameCtrl,
                label: 'ชื่อ-นามสกุล (Display Name)',
                prefixIcon: Icons.badge,
              ),
              const SizedBox(height: 15),

              if (!_isEditing)
                CustomTextField(
                  controller: _passwordCtrl,
                  obscureText: !_isPasswordVisible,
                  label: 'รหัสผ่าน (Password)',
                  prefixIcon: Icons.key,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              if (!_isEditing) const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_selectedRole),
                      isExpanded: true,
                      initialValue: _selectedRole,
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
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (val) {
                        if (val != null) setState(() => _isActive = val);
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),

              if (_isPermLoading)
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
                    _buildPermToggle('sale', 'ขายสินค้า'),
                    _buildPermToggle('void_item', 'ลบรายการ (Item)'),
                    _buildPermToggle('void_bill', 'ยกเลิกบิล'),
                    _buildPermToggle('view_cost', 'ดูต้นทุน'),
                    _buildPermToggle('view_profit', 'ดูกำไร/ยอด'),
                    _buildPermToggle('manage_product', 'จัดการสินค้า'),
                    _buildPermToggle('manage_stock', 'คลังสินค้า'),
                    _buildPermToggle('manage_user', 'จัดการพนักงาน'),
                    _buildPermToggle('manage_settings', 'ตั้งค่าระบบ'),
                    _buildPermToggle('pos_discount', 'ทำส่วนลด'),
                    _buildPermToggle('open_drawer', 'เปิดลิ้นชัก'),
                    _buildPermToggle('create_po', 'สร้างใบสั่งซื้อ'),
                    _buildPermToggle('receive_stock', 'รับเข้าสต็อก'),
                    _buildPermToggle('return_stock', 'รับคืนสินค้า'),
                    _buildPermToggle('adjust_stock', 'ปรับสต็อก'),
                    _buildPermToggle('view_stock_card', 'Stock Card'),
                    _buildPermToggle('import_product', 'นำเข้าสินค้า'),
                    _buildPermToggle('print_barcode', 'พิมพ์บาร์โค้ด'),
                    _buildPermToggle('manage_customer', 'รายชื่อลูกค้า'),
                    _buildPermToggle('customer_debt', 'ลูกหนี้/เครดิต'),
                    _buildPermToggle('billing_note', 'ใบวางบิล'),
                    _buildPermToggle('import_customer', 'นำเข้าลูกค้า'),
                    _buildPermToggle('audit_log', 'ดู Log ประวัติ'),
                    // --- Dashboard Tabs ---
                    _buildPermToggle('dashboard_view_summary', 'Dash: สรุปยอด'),
                    _buildPermToggle('dashboard_view_trend', 'Dash: กราฟ'),
                    _buildPermToggle('dashboard_view_ai', 'Dash: AI'),
                    _buildPermToggle('dashboard_view_best_selling', 'Dash: ขายดี'),
                    // --- Sales History Actions ---
                    _buildPermToggle('history_view_detail', 'ประวัติ: ดูบิล'),
                    _buildPermToggle('history_reprint', 'ประวัติ: พิมพ์ซ้ำ'),
                    _buildPermToggle('history_send_delivery', 'ประวัติ: ส่งขนส่ง'),
                    _buildPermToggle('history_send_pickup', 'ประวัติ: ส่งหลังร้าน'),
                    _buildPermToggle('history_delete_bill', 'ประวัติ: ลบบิล'),
                    _buildPermToggle('history_edit_customer', 'ประวัติ: แก้ไขลูกค้า'),
                    _buildPermToggle('edit_unpaid_order', 'ประวัติ: แก้ไขรายการบิล'),
                    // --- Delivery Report ---
                    _buildPermToggle('view_delivery_report', 'ระบบขนส่ง'),
                    _buildPermToggle('delivery_dashboard', 'ติดตามงานส่ง'),
                    _buildPermToggle('delivery_report', 'รายงานขนส่ง'),
                    _buildPermToggle('delivery_pending', 'รอส่ง/กำลังส่ง'),
                    _buildPermToggle('delivery_report_reminder', 'แจ้งเตือนสิ้นเดือน'),
                    _buildPermToggle('delivery_report_export', 'Export ขนส่ง'),
                    _buildPermToggle('manage_master_data', 'จัดการข้อมูลหลัก (Master Data)'),
                    // --- New Granular Settings Permissions ---
                    _buildPermToggle('access_settings_menu', 'เข้าเมนูตั้งค่า'),
                    _buildPermToggle('settings_connection', 'ตั้งค่า: การเชื่อมต่อ'),
                    _buildPermToggle('settings_shop_info', 'ตั้งค่า: ร้านค้า'),
                    _buildPermToggle('settings_payment', 'ตั้งค่า: การเงิน'),
                    _buildPermToggle('settings_printer', 'ตั้งค่า: เครื่องพิมพ์'),
                    _buildPermToggle('settings_general', 'ตั้งค่า: ทั่วไป'),
                    _buildPermToggle('settings_display', 'ตั้งค่า: หน้าจอ'),
                    _buildPermToggle('settings_system', 'ตั้งค่า: ระบบ'),
                    _buildPermToggle('settings_scanner', 'ตั้งค่า: บาร์โค้ด'),
                    _buildPermToggle('settings_expenses', 'ตั้งค่า: ค่าใช้จ่าย'),
                    _buildPermToggle('settings_ai', 'ตั้งค่า: AI'),
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
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: _isSaving ? 'กำลังบันทึก...' : 'บันทึก',
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
