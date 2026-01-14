import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/auth_provider.dart';

// Import หน้าจอตั้งค่าย่อยๆ
import 'shop_info_screen.dart';
import 'payment_settings_screen.dart';
import 'general_settings_screen.dart';
import 'printer_settings_screen.dart';
import 'system_settings_screen.dart';
import 'display_settings_screen.dart';
import 'barcode_settings_screen.dart';
import 'expense_management_screen.dart';
import 'connection_settings_screen.dart';
import 'activity_log_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  // --------------------------------------------------------
  // ✅ แก้ไขส่วนนี้: เพิ่มการดึงค่า phone, name80, address80
  // --------------------------------------------------------
  static Future<double> getVatRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('vat_rate') ?? 7.0;
  }

  static Future<Map<String, String>> getShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      // ข้อมูลทั่วไป (สำหรับ A4/A5 หรือค่าเริ่มต้น)
      'name': prefs.getString('shop_name') ?? 'S-Link POS Store',
      'address': prefs.getString('shop_address') ?? '123 Phetchabun, Thailand',
      'taxId': prefs.getString('shop_tax_id') ?? '',
      'phone': prefs.getString('shop_phone') ?? '', // ✅ เพิ่มเบอร์โทร
      'footer':
          prefs.getString('shop_footer') ?? 'Thank you for your business.',

      // ข้อมูลเฉพาะ 80mm (สำหรับใบเสร็จอย่างย่อ)
      'name80': prefs.getString('shop_name_80mm') ?? '', // ✅ เพิ่มชื่อย่อ
      'address80':
          prefs.getString('shop_address_80mm') ?? '', // ✅ เพิ่มที่อยู่ย่อ
    };
  }
  // --------------------------------------------------------

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ (Settings)',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              crossAxisCount: 5,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.3,
              children: [
                _buildMenuCard(
                  context,
                  label: 'ข้อมูลร้านค้า\n(Shop Profile)',
                  icon: Icons.store,
                  color: Colors.blue,
                  permissionKey: 'settings_shop_info',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShopInfoScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'การรับเงิน & QR\n(Payment)',
                  icon: Icons.qr_code_2,
                  color: Colors.green,
                  permissionKey: 'settings_payment',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaymentSettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'เครื่องพิมพ์\n(Printers)',
                  icon: Icons.print,
                  color: Colors.indigo,
                  permissionKey: 'settings_printer',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrinterSettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'ทั่วไป (VAT)\n(General)',
                  icon: Icons.settings_applications,
                  color: Colors.orange,
                  permissionKey: 'settings_general',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GeneralSettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'หน้าจอ & ธีม\n(Display)',
                  icon: Icons.monitor,
                  color: Colors.purple,
                  permissionKey: 'settings_display',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DisplaySettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'ระบบ & ผู้ใช้\n(System)',
                  icon: Icons.security,
                  color: Colors.red,
                  permissionKey: 'settings_system',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SystemSettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'เครื่องอ่านบาร์โค้ด\n(Scanner)',
                  icon: Icons.qr_code_scanner,
                  color: Colors.blueGrey,
                  permissionKey: 'settings_scanner',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BarcodeSettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'จัดการค่าใช้จ่าย\n(Expenses)',
                  icon: Icons.money_off,
                  color: Colors.redAccent,
                  permissionKey: 'settings_expenses',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExpenseManagementScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'การเชื่อมต่อ\n(Connection)',
                  icon: Icons.cloud_sync,
                  color: Colors.teal,
                  permissionKey: 'settings_connection',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConnectionSettingsScreen())),
                ),
                _buildMenuCard(
                  context,
                  label: 'Log ระบบ\n(System Log)',
                  icon: Icons.history,
                  color: Colors.blueGrey,
                  permissionKey: 'settings_system',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivityLogScreen())),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String permissionKey,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final hasAccess = auth.hasPermission(permissionKey);

    return Material(
      color: hasAccess ? Colors.white : Colors.grey[200],
      elevation: hasAccess ? 4 : 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasAccess
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('คุณไม่มีสิทธิ์เข้าถึงเมนูนี้ (Access Denied)'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
        hoverColor:
            hasAccess ? color.withValues(alpha: 0.05) : Colors.transparent,
        splashColor:
            hasAccess ? color.withValues(alpha: 0.1) : Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: hasAccess ? Colors.grey.shade100 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: hasAccess
                        ? color.withValues(alpha: 0.1)
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 48,
                    color: hasAccess ? color : Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasAccess ? Colors.grey[800] : Colors.grey,
                  ),
                ),
                if (!hasAccess)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.lock, size: 16, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
