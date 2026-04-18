import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/auth_provider.dart';

import 'backup_settings_screen.dart';
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
import 'fuel_management_screen.dart';
import '../promotions/reward_management_screen.dart';

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
      'name': prefs.getString('shop_name') ?? 'ร้านส.บริการ ท่าข้าม',
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
              final auth = Provider.of<AuthProvider>(context);

              // Define all menu items
              final List<Widget> menuItems = [];

              if (auth.hasPermission('settings_shop_info')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'ข้อมูลร้านค้า\n(Shop Profile)',
                  icon: Icons.store,
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShopInfoScreen())),
                ));
              }

              if (auth.hasPermission('settings_payment')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'การรับเงิน & QR\n(Payment)',
                  icon: Icons.qr_code_2,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaymentSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_printer')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'เครื่องพิมพ์\n(Printers)',
                  icon: Icons.print,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrinterSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_general')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'ทั่วไป (VAT)\n(General)',
                  icon: Icons.settings_applications,
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GeneralSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_display')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'หน้าจอ & ธีม\n(Display)',
                  icon: Icons.monitor,
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DisplaySettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_system')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'ระบบ & ผู้ใช้\n(System)',
                  icon: Icons.security,
                  color: Colors.red,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SystemSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_scanner')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'เครื่องอ่านบาร์โค้ด\n(Scanner)',
                  icon: Icons.qr_code_scanner,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BarcodeSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_expenses')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'จัดการค่าใช้จ่าย\n(Expenses)',
                  icon: Icons.money_off,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExpenseManagementScreen())),
                ));
              }

              if (auth.hasPermission('settings_connection')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'การเชื่อมต่อ\n(Connection)',
                  icon: Icons.cloud_sync,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConnectionSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_system')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'จัดการข้อมูล\n(Backup & DB)',
                  icon: Icons.storage,
                  color: Colors.brown,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BackupSettingsScreen())),
                ));
              }

              if (auth.hasPermission('settings_system')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'Log ระบบ\n(System Log)',
                  icon: Icons.history,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivityLogScreen())),
                ));
              }

              // ⛽ Fuel Management
              if (auth.hasPermission('settings_expenses')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'จัดการน้ำมัน\n(Fuel & Vehicles)',
                  icon: Icons.local_gas_station,
                  color: Colors.amber.shade700,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FuelManagementScreen())),
                ));
              }

              // 🎁 Reward Management
              if (auth.hasPermission('settings_system')) {
                menuItems.add(_buildMenuCard(
                  context,
                  label: 'จัดการของรางวัล\n(Rewards Backend)',
                  icon: Icons.card_giftcard,
                  color: Colors.pink,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RewardManagementScreen())),
                ));
              }

              return GridView.count(
                crossAxisCount: 5,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.3,
                children: menuItems,
              );
            },
          )),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    // permissionKey is removed as we filter externally
  }) {
    // Only accessible items reach here, so we display them openly.

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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 48,
                    color: color,
                  ),
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
      ),
    );
  }
}
