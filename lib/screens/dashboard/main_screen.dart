import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../../state/auth_provider.dart';
import '../../state/navigation_provider.dart';

// import หน้าจออื่นๆ
import '../pos/pos_checkout_screen.dart';
import 'dashboard_screen.dart';
import '../products/product_management_screen.dart';
import '../customers/customer_management_screen.dart';
import '../suppliers/supplier_list_view.dart';

import '../reports/logistics_menu_screen.dart';
import '../settings/settings_screen.dart';
import '../hr/hr_screen.dart'; // ✅ HR Module

import 'package:window_manager/window_manager.dart'; // ✅ For WindowListener
import '../../services/customer_display_service.dart';
import '../../services/mysql_service.dart';
import '../../services/firebase_service.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../pos/pos_state_manager.dart';
import 'package:auto_updater/auto_updater.dart';
import '../../services/alert_service.dart';
import '../../services/integration/fingerprint_network_service.dart';
import '../../widgets/fingerprint/fingerprint_action_card.dart';
import '../../widgets/fingerprint/fingerprint_disconnect_banner.dart';
import '../../controllers/fingerprint_overlay_controller.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WindowListener {
  Key _refreshKey = UniqueKey(); // ✅ Key สำหรับบังคับ Rebuild

  // Fingerprint overlay controller (แยก logic ออกจาก UI)
  final _fingerprintController = FingerprintOverlayController();

  // Fingerprint action overlay (non-blocking floating card)
  OverlayEntry? _fingerprintActionOverlay;

  // Fingerprint disconnect banner
  OverlayEntry? _fingerprintDisconnectOverlay;

  // ✅ Task 5: สร้าง Delivery Service (ใช้ Singleton Pattern เดียวกับส่วนอื่นใน app)
  final DeliveryIntegrationService _deliveryService = DeliveryIntegrationService(
    MySQLService(),
    FirebaseService(),
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); // ✅ Add Listener
    _setupFingerprintListeners();
  }

  /// ดักฟัง callbacks ทั้งหมดจาก FingerprintAttendanceService และ FingerprintNetworkService
  /// โดยมอบหมาย Logic ให้ FingerprintOverlayController จัดการ
  void _setupFingerprintListeners() {
    _fingerprintController.setup(
      context,
      ref,
      onActionRequired: _showFingerprintActionOverlay,
      onConnectionChanged: (isConn, address) {
        if (isConn) {
          _dismissFingerprintDisconnectBanner();
        } else {
          _showFingerprintDisconnectedBanner();
        }
      },
    );
  }



  @override
  void dispose() {
    windowManager.removeListener(this); // ✅ Remove Listener
    _deliveryService.dispose(); // ✅ Task 5: ยกเลิก Timer
    _fingerprintController.dispose(); // ✅ ยกเลิก Fingerprint Listeners ผ่าน Controller
    _fingerprintActionOverlay?.remove();
    _fingerprintActionOverlay = null;
    _fingerprintDisconnectOverlay?.remove();
    _fingerprintDisconnectOverlay = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fingerprint Disconnect Banner
  // ---------------------------------------------------------------------------

  /// แสดง banner แจ้งเตือนที่มุมบนขวา เมื่อการเชื่อมต่อเครื่องสแกนหลุด
  void _showFingerprintDisconnectedBanner() {
    if (_fingerprintDisconnectOverlay != null) return; // มีอยู่แล้ว ไม่ซ้ำ

    _fingerprintDisconnectOverlay = OverlayEntry(
      builder: (_) => Positioned(
        top: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: FingerprintDisconnectBanner(
            onReconnect: () async {
              _dismissFingerprintDisconnectBanner();
              // เริ่ม auto-discovery ใหม่ — จะต่อกลับทันทีเมื่อ ESP32 ตอบ
              FingerprintNetworkService().startAutoDiscovery();
              if (mounted) {
                AlertService.show(
                  context: context,
                  message: '🔍 กำลังค้นหาเครื่องสแกนลายนิ้วมือในวง LAN...',
                  type: 'info',
                  duration: const Duration(seconds: 3),
                );
              }
            },
            onDismiss: _dismissFingerprintDisconnectBanner,
          ),
        ),
      ),
    );

    // ต้อง defer ไว้ 1 frame เพราะ Overlay อาจยังไม่ mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fingerprintDisconnectOverlay != null) {
        Overlay.of(context).insert(_fingerprintDisconnectOverlay!);
      }
    });
  }

  void _dismissFingerprintDisconnectBanner() {
    _fingerprintDisconnectOverlay?.remove();
    _fingerprintDisconnectOverlay = null;
  }

  // ---------------------------------------------------------------------------
  // Fingerprint Action Overlay
  // ---------------------------------------------------------------------------

  /// แสดง floating card ที่มุมล่างขวา โดยไม่ขวางหน้าจอ POS

  void _showFingerprintActionOverlay(
    String name,
    String currentStatus,
    void Function(String action) onActionSelected,
  ) {
    // ถ้ามี overlay เก่าอยู่ ให้เอาออกก่อน (เผื่อสแกนซ้อนกัน)
    _fingerprintActionOverlay?.remove();
    _fingerprintActionOverlay = null;

    // Toast แจ้งเตือนเล็กๆ ด้านซ้ายล่างว่ามีคนสแกน
    final statusText = currentStatus == 'CLOCK_IN' ? 'กำลังทำงานอยู่' : 'ออกชั่วคราวอยู่';
    AlertService.show(
      context: context,
      message: '👆 $name สแกนนิ้วแล้ว ($statusText)',
      type: 'info',
      duration: const Duration(seconds: 3),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 20,
        right: 20,
        child: FingerprintActionCard(
          employeeName: name,
          currentStatus: currentStatus,
          autoTimeoutSeconds: 300, // 5 นาที
          onActionSelected: (action) {
            entry.remove();
            if (_fingerprintActionOverlay == entry) {
              _fingerprintActionOverlay = null;
            }
            if (action != 'DISMISS') {
              onActionSelected(action);
            }
          },
        ),
      ),
    );

    _fingerprintActionOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  @override
  void onWindowClose() async {
    // ✅ Close Customer Display when Main Close
    await CustomerDisplayService().closeDisplay();
    super.onWindowClose();
  }

  /// แสดง Dialog ยืนยันออกจากระบบพร้อมปุ่มยืนยัน Logout
  void _showLogoutDialog(BuildContext context) {
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
                  if (mounted) ref.read(authProvider.notifier).logout();
                },
              );
            },
            child: const Text('ออก'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      AlertService.show(
          context: context, message: 'กำลังตรวจสอบเวอร์ชัน...', type: 'info');
      String feedUrl =
          'https://raw.githubusercontent.com/mi130830-bit/s-mart-pos/main/appcast.xml';
      await autoUpdater.setFeedURL(feedUrl);

      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ ก่อนอัปเดต'),
          content: const Text(
            'หากแอปติดตั้งใน C:\\Program Files\n'
            'กรุณาปิดแอปแล้วเปิดใหม่โดยคลิกขวา\n'
            'เลือก "Run as Administrator" ก่อนกดอัปเดต\n\n'
            'ถ้าเปิดด้วยสิทธิ์ Admin แล้ว กด "ตกลง" ได้เลย',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                autoUpdater.checkForUpdates();
              },
              child: const Text('ตกลง, อัปเดตเลย'),
            ),
          ],
        ),
      );
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
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;

    if (user == null) {
      // This block is for when the user is not logged in.
      // The user's requested change seems to be intended for this state.
      final posState = ref.watch(posProvider);
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
    final bool isUserHR = user.role == 'HR';
    final bool isSignedIn = authState.isAuthenticated;

    final bool showDashboard = user.canViewProfit ||
        isUserAdmin ||
        authState.hasPermission('view_sales_history');
    final bool showProductStock = isSignedIn;

    final bool canAccessSettings =
        isUserAdmin || authState.hasPermission('access_settings_menu');
    
    final bool canViewDeliveryReport =
        isUserAdmin || authState.hasPermission('view_delivery_report');
    
    final bool canAccessHR = isUserAdmin || isUserHR;

    // ✅ Payday Alert Check (แจ้งเตือนวันจ่ายเงิน)
    final today = DateTime.now();
    final bool isWeeklyPayday = today.weekday == DateTime.saturday;
    final bool isMonthlyPayday = today.day == 1;
    final bool hasPaydayAlert = isWeeklyPayday || isMonthlyPayday;

    // ✅ 1. เรียงลำดับหน้าจอ (Screens) ใหม่ตามคำขอ
    final List<Widget> screens = [
      const PosCheckoutScreen(), // 1. จุดขาย
      if (showProductStock) const ProductManagementScreen(), // 2. สินค้า/คลัง
      const CustomerManagementScreen(), // 3. ลูกค้า
      if (showDashboard)
        const DashboardScreen(), // 4. ประวัติการขาย
      if (isUserAdmin) const SupplierListView(), // 5. จัดการผู้ขาย
      if (canViewDeliveryReport)
        LogisticsMenuScreen(deliveryService: _deliveryService), // 6. ขนส่ง (Logistics)
      if (canAccessHR) const HrScreen(), // 8. บุคคล (HR)
      if (canAccessSettings)
        const SettingsScreen(), // 9. ตั้งค่า
    ];

    // ✅ 2. เรียงลำดับเมนู (Destinations) ให้ตรงกับ Screens
    final List<NavigationRailDestination> destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.shopping_cart),
        label: Text('หน้าขาย (POS)'),
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
      if (isUserAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.store),
          label: Text('จัดการผู้ขาย'),
        ),
      if (canViewDeliveryReport)
        const NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          label: Text('ขนส่ง'),
        ),
      if (canAccessHR)
        NavigationRailDestination(
          icon: hasPaydayAlert 
              ? const Badge(
                  label: Text('!'), 
                  child: Icon(Icons.badge)
                ) 
              : const Icon(Icons.badge),
          label: const Text('บุคคล'),
        ),
      if (canAccessSettings)
        const NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('ตั้งค่า'),
        ),
    ];

    final int selectedIndex = ref.watch(mainNavigationProvider);
    // ป้องกัน Error กรณีสิทธิ์เปลี่ยนแล้ว Index เกิน
    if (selectedIndex >= screens.length) {
      Future.microtask(() => ref.read(mainNavigationProvider.notifier).state = 0);
    }

    final posState = ref.watch(posProvider);

    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      // ปรับความกว้างเมนูซ้ายให้ไม่อึดอัด (ตามที่เคยคุยกันไว้)
                      minWidth: 110,
                      selectedIndex: selectedIndex < screens.length ? selectedIndex : 0,
                      onDestinationSelected: (index) {
                        if (selectedIndex == index) {
                          // ✅ กดเมนูเดิม -> Force Rebuild หน้าจอ
                          setState(() {
                            _refreshKey = UniqueKey();
                          });
                        } else {
                          // ✅ กดเปลี่ยนเมนู -> เปลี่ยน Index
                          ref.read(mainNavigationProvider.notifier).state = index;
                        }
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
                      leading: _buildRailLeading(
                        shopName: posState.shopName,
                        displayName: user.displayName,
                        role: user.role,
                      ),
                      destinations: destinations,
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _buildRailTrailing(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: KeyedSubtree(
              key: _refreshKey, // ✅ Force Rebuild Here
              child: screens[selectedIndex < screens.length ? selectedIndex : 0],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper Widget methods สำหรับ NavigationRail
// ---------------------------------------------------------------------------
extension _MainScreenStateHelpers on _MainScreenState {
  /// สร้าง leading section สำหรับ NavigationRail: ชื่อร้าน, User, Role
  Widget _buildRailLeading({
    required String shopName,
    required String displayName,
    required String role,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              shopName,
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
          'User: $displayName',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          'Role: $role',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRailTrailing() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.system_update, color: Colors.blue, size: 20),
            tooltip: 'ตรวจสอบเวอร์ชัน',
            onPressed: () => _checkForUpdates(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red, size: 20),
            tooltip: 'ออกจากระบบ',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }
}
