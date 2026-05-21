import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_provider.dart';
import 'customer_list_view.dart'; // ไฟล์ใหม่ (ข้อ 2)
import 'debtor_list_screen.dart'; // ไฟล์ใหม่ (ข้อ 3)
import 'billing/billing_list_screen.dart'; // [NEW] Billing Screen
import 'customer_import_screen.dart'; // [NEW] Import Screen
import '../../repositories/customer_repository.dart';
import '../../services/alert_service.dart';
import '../../widgets/dialogs/admin_pin_dialog.dart';

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends ConsumerState<CustomerManagementScreen> {
  String _currentView = 'MENU';

  // กลับไปหน้าเมนู
  void _goBack() {
    if (_currentView == 'MENU') {
      // ถ้าอยู่หน้าเมนูแล้วกด Back ให้เรียก willPop หรือแจ้ง Parent
    } else {
      setState(() => _currentView = 'MENU');
    }
  }

  void _confirmResetPoints() async {
    // 1. Ask for Admin PIN
    final isAuthorized = await AdminPinDialog.show(
      context,
      title: 'ยืนยันสิทธิ์',
      message: 'กรุณากรอกรหัสผ่านแอดมินเพื่อล้างคะแนนสะสม',
    );

    if (!isAuthorized) {
      if (mounted) {
         AlertService.show(context: context, message: 'รหัสผ่านไม่ถูกต้อง หรือยกเลิกการทำรายการ', type: 'error');
      }
      return;
    }

    // 2. Confirm Dialog
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการล้างคะแนนสะสม', style: TextStyle(color: Colors.red)),
        content: const Text('คุณต้องการล้างคะแนนสะสมของลูกค้าทุกคนให้เป็น 0 ใช่หรือไม่?\n\n(ระบบจะรีเซ็ตคะแนนสะสมทั้งหมด การกระทำนี้ไม่สามารถย้อนกลับได้)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ล้างคะแนน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final repo = CustomerRepository();
      final affected = await repo.clearAllPoints();
      if (mounted) {
         AlertService.show(context: context, message: 'ล้างคะแนนสะสมเรียบร้อยแล้ว (อัปเดต $affected รายการ)', type: 'success');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการลูกค้า & ลูกหนี้',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: _currentView != 'MENU'
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null, // ถ้าเป็น Main Screen อาจจะไม่ต้องมีปุ่ม Back ตรงนี้ หรือใช้ Default
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case 'LIST':
        return const CustomerListView();
      case 'DEBTOR':
        return const DebtorListScreen();
      case 'BILLING': // [NEW]
        return const BillingListScreen();
      default:
        return _buildMainMenu();
    }
  }

  Widget _buildMainMenu() {
    final auth = ref.watch(authProvider);

    // สร้างรายการเมนูตามสิทธิ์ที่มี (เหมือนหน้า Stock)
    final List<Widget> menuItems = [
      if (auth.hasPermission('manage_customer'))
        _buildMenuCard(
          label: 'รายชื่อลูกค้า/ลูกหนี้\n(Customers & Debtors)',
          icon: Icons.people_alt,
          color: Colors.blue,
          onTap: () => setState(() => _currentView = 'LIST'),
        ),
      if (auth.hasPermission('manage_customer'))
        _buildMenuCard(
          label: 'รายการลูกหนี้\n(Debtor List)',
          icon: Icons.account_balance_wallet,
          color: Colors.orange,
          onTap: () => setState(() => _currentView = 'DEBTOR'),
        ),
      if (auth.hasPermission('billing_note'))
        _buildMenuCard(
          label: 'ใบวางบิล\n(Billing Notes)',
          icon: Icons.description,
          color: Colors.purple,
          onTap: () => setState(() => _currentView = 'BILLING'),
        ),
      if (auth.hasPermission('import_customer'))
        _buildMenuCard(
          label: 'นำเข้าข้อมูล\n(Import CSV)',
          icon: Icons.upload_file,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerImportScreen()),
            );
          },
        ),
      if (auth.hasPermission('manage_customer'))
        _buildMenuCard(
          label: 'ล้างคะแนนสะสม\n(Reset Points)',
          icon: Icons.cleaning_services,
          color: Colors.red,
          onTap: _confirmResetPoints,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.count(
            crossAxisCount: 5,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.3,
            children: menuItems,
          );
        },
      ),
    );
  }

  Widget _buildMenuCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: color.withValues(alpha: 0.05),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
