import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import 'product_list_view.dart';
import 'stock_ops_view.dart';
import 'product_import_screen.dart';
import 'barcode_printing_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  String _currentView = 'MENU';

  // ชื่อ Title Bar เปลี่ยนตามหน้า
  String get _appBarTitle {
    switch (_currentView) {
      case 'LIST':
        return 'จัดการสินค้า (Products)';
      case 'ADJUST':
        return 'เช็ค/ปรับปรุงสต็อก (Adjust)';
      case 'ADD':
        return 'รับเข้าสินค้า (Stock In)';
      case 'RETURN':
        return 'รับคืนสินค้า (Return In)';
      case 'CARD':
        return 'รายงาน Stock Card';
      case 'IMPORT': // ✅ 2. เพิ่มชื่อหัวข้อ
        return 'นำเข้าสินค้าจากไฟล์ (Import)';
      case 'BARCODE':
        return 'พิมพ์บาร์โค้ด (Print Barcode)';
      default:
        return 'เมนูคลังสินค้า';
    }
  }

  void _navigateTo(String view) => setState(() => _currentView = view);

  // กด Back จะกลับมาหน้า Menu ก่อน
  void _goBack() {
    if (_currentView == 'MENU') {
      Navigator.pop(context);
    } else {
      setState(() => _currentView = 'MENU');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: _currentView != 'MENU'
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        automaticallyImplyLeading: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // เลือกหน้าจอที่จะแสดงตาม State
    switch (_currentView) {
      case 'LIST':
        return const ProductListSection();
      case 'ADJUST':
        return const StockOperationTab(operationType: 'ADJUST');
      case 'ADD':
        return const StockOperationTab(operationType: 'ADD');
      case 'RETURN':
        return const StockOperationTab(operationType: 'RETURN');
      case 'CARD':
        return const StockOperationTab(operationType: 'CARD');
      case 'IMPORT': // ✅ 3. เรียกหน้าจอ Import
        return const ProductImportScreen();
      case 'BARCODE':
        return const BarcodePrintingScreen();
      default:
        return _buildMenu();
    }
  }

  Widget _buildMenu() {
    final auth = Provider.of<AuthProvider>(context);

    // List of visible menu items
    final List<Widget> menuItems = [
      if (auth.hasPermission('manage_product'))
        _buildMenuCard(
          label: 'รายการสินค้า\n(Product List)',
          icon: Icons.list_alt,
          color: Colors.blue,
          onTap: () => _navigateTo('LIST'),
        ),
      if (auth.hasPermission('receive_stock'))
        _buildMenuCard(
          label: 'รับเข้าสินค้า\n(Stock In)',
          icon: Icons.add_box,
          color: Colors.green,
          onTap: () => _navigateTo('ADD'),
        ),
      if (auth.hasPermission('return_stock'))
        _buildMenuCard(
          label: 'รับคืนสินค้า\n(Return In)',
          icon: Icons.assignment_return,
          color: Colors.orange,
          onTap: () => _navigateTo('RETURN'),
        ),
      if (auth.hasPermission('adjust_stock'))
        _buildMenuCard(
          label: 'เช็ค/ปรับสต็อก\n(Adjust)',
          icon: Icons.inventory,
          color: Colors.purple,
          onTap: () => _navigateTo('ADJUST'),
        ),
      if (auth.hasPermission('view_stock_card'))
        _buildMenuCard(
          label: 'ความเคลื่อนไหว\n(Stock Card)',
          icon: Icons.history,
          color: Colors.brown,
          onTap: () => _navigateTo('CARD'),
        ),
      if (auth.hasPermission('import_product'))
        _buildMenuCard(
          label: 'นำเข้าสินค้า\n(Import Excel)',
          icon: Icons.cloud_upload,
          color: Colors.teal,
          onTap: () => _navigateTo('IMPORT'),
        ),
      if (auth.hasPermission('print_barcode'))
        _buildMenuCard(
          label: 'พิมพ์บาร์โค้ด\n(Barcodes)',
          icon: Icons.qr_code_2,
          color: Colors.deepPurple,
          onTap: () => _navigateTo('BARCODE'),
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
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
