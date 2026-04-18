import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';

// import หน้าจออื่นๆ
import '../pos/pos_checkout_screen.dart';
import 'dashboard_screen.dart';
import '../products/product_management_screen.dart';
import '../customers/customer_management_screen.dart';
import '../suppliers/supplier_list_view.dart';

import '../reports/logistics_menu_screen.dart';
import '../settings/settings_screen.dart';

import 'package:window_manager/window_manager.dart'; // ✅ For WindowListener
import '../../services/customer_display_service.dart';
import '../../services/mysql_service.dart';
import '../../services/firebase_service.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../pos/pos_state_manager.dart';
import 'package:auto_updater/auto_updater.dart';
import '../../services/alert_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WindowListener, TickerProviderStateMixin {
  int _selectedIndex = 0;
  Key _refreshKey = UniqueKey(); // ✅ Key สำหรับบังคับ Rebuild
  late TabController _tabController;

  // ✅ Task 5: สร้าง Delivery Service (ใช้ Singleton Pattern เดียวกับส่วนอื่นใน app)
  final DeliveryIntegrationService _deliveryService = DeliveryIntegrationService(
    MySQLService(),
    FirebaseService(),
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); // ✅ Add Listener
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    // This method is a placeholder for now, it will be implemented later
    // when the TabController is fully integrated.
  }

  @override
  void dispose() {
    windowManager.removeListener(this); // ✅ Remove Listener
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _deliveryService.dispose(); // ✅ Task 5: ยกเลิก Timer
    super.dispose();
  }

  // ... (rest of initState / _checkAutoOpenDisplay) ...

  @override
  void onWindowClose() async {
    // ✅ Close Customer Display when Main Close
    await CustomerDisplayService().closeDisplay();
    super.onWindowClose();
  }

  /* 
  Future<void> _checkAutoOpenDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to TRUE as per user request to auto-open
    final autoOpen = prefs.getBool('auto_open_customer_display') ?? true;
    if (autoOpen) {
      // Small delay to ensure app is ready
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        await CustomerDisplayService().openDisplay();
      }
    }
  }
  */

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      AlertService.show(
          context: context, message: 'กำลังตรวจสอบเวอร์ชัน...', type: 'info');
      String feedUrl =
          'https://raw.githubusercontent.com/mi130830-bit/s-mart-pos/main/appcast.xml';
      await autoUpdater.setFeedURL(feedUrl);
      await autoUpdater.checkForUpdates();
    } catch (e) {
      debugPrint('Update Error: $e');
      if (context.mounted) {
        AlertService.show(
            context: context,
            message: 'ไม่สามารถตรวจสอบได้: $e',
            type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user == null) {
      // This block is for when the user is not logged in.
      // The user's requested change seems to be intended for this state.
      final posState = Provider.of<PosStateManager>(context);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              Text(
                'เข้าสู่ระบบ ${posState.shopName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'เข้าสู่ระบบเพื่อใช้งาน',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(), // Keep a loading indicator
            ],
          ),
        ),
      );
    }

    final bool isUserAdmin = user.role == 'ADMIN';
    final bool isSignedIn = auth.isAuthenticated;

    final bool showDashboard = user.canViewProfit ||
        isUserAdmin ||
        auth.hasPermission('view_sales_history');
    final bool showProductStock = isSignedIn;

    final bool canAccessSettings =
        isUserAdmin || auth.hasPermission('access_settings_menu');
    
    final bool canViewDeliveryReport =
        isUserAdmin || auth.hasPermission('view_delivery_report');

    // ✅ 1. เรียงลำดับหน้าจอ (Screens) ใหม่ตามคำขอ
    final List<Widget> screens = [
      const PosCheckoutScreen(), // 1. จุดขาย
      if (showProductStock) const ProductManagementScreen(), // 2. สินค้า/คลัง
      const CustomerManagementScreen(), // 3. ลูกค้า
      if (showDashboard)
        const DashboardScreen(), // 4. ประวัติการขาย
      if (canViewDeliveryReport)
        LogisticsMenuScreen(deliveryService: _deliveryService), // 5. ขนส่ง (Logistics)
      if (isUserAdmin) const SupplierListView(), // 6. จัดการผู้ขาย
      if (canAccessSettings)
        const SettingsScreen(), // 7. ตั้งค่า
    ];

    // ✅ 2. เรียงลำดับเมนู (Destinations) ให้ตรงกับ Screens
    final List<NavigationRailDestination> destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.shopping_cart),
        label: Text('จุดขาย (POS)'),
      ),
      if (showProductStock)
        const NavigationRailDestination(
          icon: Icon(Icons.inventory),
          label: Text('สินค้า/คลัง'),
        ),
      const NavigationRailDestination(
        icon: Icon(Icons.people),
        label: Text('ลูกค้า'),
      ),
      if (showDashboard)
        const NavigationRailDestination(
          icon: Icon(Icons.receipt_long),
          label: Text('ประวัติการขาย'),
        ),
      if (canViewDeliveryReport)
        const NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          label: Text('ขนส่ง'),
        ),
      if (isUserAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.store),
          label: Text('จัดการผู้ขาย'),
        ),
      if (canAccessSettings)
        const NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('ตั้งค่า'),
        ),
    ];

    // ป้องกัน Error กรณีสิทธิ์เปลี่ยนแล้ว Index เกิน
    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    final posState = Provider.of<PosStateManager>(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            // ปรับความกว้างเมนูซ้ายให้ไม่อึดอัด (ตามที่เคยคุยกันไว้)
            minWidth: 110,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                if (_selectedIndex == index) {
                  // ✅ กดเมนูเดิม -> Force Rebuild หน้าจอ
                  _refreshKey = UniqueKey();
                } else {
                  // ✅ กดเปลี่ยนเมนู -> เปลี่ยน Index
                  _selectedIndex = index;
                }
              });
            },
            labelType: NavigationRailLabelType.all,
            selectedLabelTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            leading: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      posState.shopName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                Text(
                  'User: ${user.displayName}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Role: ${user.role}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            trailing: Column(
              children: [
                //const Spacer(),
                IconButton(
                  icon: const Icon(Icons.system_update, color: Colors.blue),
                  tooltip: 'ตรวจสอบเวอร์ชัน',
                  onPressed: () => _checkForUpdates(context),
                ),
                const Text('Update',
                    style: TextStyle(fontSize: 10, color: Colors.blue)),
                const SizedBox(height: 10),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'ออกจากระบบ',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ยืนยันการออก'),
                        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('ยกเลิก'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Future.delayed(
                                const Duration(milliseconds: 10),
                                () {
                                  auth.logout();
                                },
                              );
                            },
                            child: const Text('ออก'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
            destinations: destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: KeyedSubtree(
              key: _refreshKey, // ✅ Force Rebuild Here
              child: screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
