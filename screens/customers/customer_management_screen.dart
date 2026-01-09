import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import 'customer_list_view.dart'; // ไฟล์ใหม่ (ข้อ 2)
import 'debtor_list_screen.dart'; // ไฟล์ใหม่ (ข้อ 3)
import 'billing_list_screen.dart'; // [NEW] Billing Screen
import 'customer_import_screen.dart'; // [NEW] Import Screen

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  String _currentView = 'MENU';

  // กลับไปหน้าเมนู
  void _goBack() {
    if (_currentView == 'MENU') {
      // ถ้าอยู่หน้าเมนูแล้วกด Back ให้เรียก willPop หรือแจ้ง Parent
    } else {
      setState(() => _currentView = 'MENU');
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
    final auth = Provider.of<AuthProvider>(context);

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
      color: Colors.white,
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
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
