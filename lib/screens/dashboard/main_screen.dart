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
import '../../services/hr/fingerprint_attendance_service.dart';
import '../../services/integration/fingerprint_network_service.dart';
import '../../widgets/fingerprint/fingerprint_action_card.dart';
import '../../state/hr/attendance_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WindowListener, TickerProviderStateMixin {
  Key _refreshKey = UniqueKey(); // ✅ Key สำหรับบังคับ Rebuild
  late TabController _tabController;

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // ดักฟังการแสกนลายนิ้วมือเพื่อแสดง Toast แจ้งเตือนบนจอ POS
    FingerprintAttendanceService().onAttendanceRecorded = (name, type) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'บันทึกสำเร็จ: คุณ $name ได้ทำการ $type แล้วครับ 🟢',
          type: 'success',
          duration: const Duration(seconds: 4),
        );
        ref.read(attendanceProvider.notifier).loadToday(); // รีเฟรชหน้าประวัติลงเวลาทำงานทันที
      }
    };
    FingerprintAttendanceService().onUnknownFingerprint = (msg) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: msg,
          type: 'warning',
          duration: const Duration(seconds: 5),
        );
      }
    };

    // ดักฟังกรณีสแกนนิ้วในสถานะกึ่งกลาง → แสดง floating card ที่มุมล่างขวา (ไม่ขวาง POS)
    // ⚠️ card จะขึ้นเฉพาะเครื่องที่ login ด้วย role ADMIN เท่านั้น
    FingerprintAttendanceService().onActionRequired = (name, currentStatus, onActionSelected) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (!authState.isAdmin) {
        // ไม่ใช่ Admin → แค่แจ้งเตือน Toast เงียบๆ ไม่ขึ้น card ให้กด
        final statusText = currentStatus == 'CLOCK_IN' ? 'กำลังทำงานอยู่' : 'ออกชั่วคราวอยู่';
        AlertService.show(
          context: context,
          message: '👆 $name สแกนนิ้วแล้ว ($statusText)',
          type: 'info',
          duration: const Duration(seconds: 3),
        );
        return;
      }
      _showFingerprintActionOverlay(name, currentStatus, onActionSelected);
    };

    // ดักฟังการเชื่อมต่อ/หลุดของเครื่องแสกนลายนิ้วมือ
    FingerprintNetworkService().onConnectionChanged = (isConn, address) {
      if (!mounted) return;
      if (isConn) {
        // เชื่อมต่อสำเร็จ → เอา banner แจ้งเตือนออก
        _dismissFingerprintDisconnectBanner();
      } else {
        // หลุด → แสดง banner พร้อมปุ่มค้นหาใหม่
        _showFingerprintDisconnectedBanner();
      }
    };
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
    FingerprintAttendanceService().onAttendanceRecorded = null;
    FingerprintAttendanceService().onUnknownFingerprint = null;
    FingerprintAttendanceService().onActionRequired = null;
    FingerprintNetworkService().onConnectionChanged = null;
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
          child: _FingerprintDisconnectBanner(
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
      if (canViewDeliveryReport)
        LogisticsMenuScreen(deliveryService: _deliveryService), // 5. ขนส่ง (Logistics)
      if (isUserAdmin) const SupplierListView(), // 6. จัดการผู้ขาย
      if (canAccessHR) const HrScreen(), // 7. บุคคล (HR)
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
          NavigationRail(
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
                                  ref.read(authProvider.notifier).logout();
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
              child: screens[selectedIndex < screens.length ? selectedIndex : 0],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _FingerprintDisconnectBanner
// Overlay widget แจ้งเตือนเมื่อเครื่องสแกนลายนิ้วมือหลุดการเชื่อมต่อ
// =============================================================================
class _FingerprintDisconnectBanner extends StatefulWidget {
  final VoidCallback onReconnect;
  final VoidCallback onDismiss;

  const _FingerprintDisconnectBanner({
    required this.onReconnect,
    required this.onDismiss,
  });

  @override
  State<_FingerprintDisconnectBanner> createState() =>
      _FingerprintDisconnectBannerState();
}

class _FingerprintDisconnectBannerState
    extends State<_FingerprintDisconnectBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fadeSlide;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeSlide = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade700, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Header ----
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fingerprint,
                          color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เครื่องสแกนหลุดการเชื่อมต่อ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'ลายนิ้วมือไม่ถูกบันทึกในขณะนี้',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ปุ่มปิด
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close,
                          color: Colors.white38, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ---- ปุ่มค้นหาใหม่ ----
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isReconnecting
                        ? null
                        : () async {
                            setState(() => _isReconnecting = true);
                            widget.onReconnect();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isReconnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 18),
                    label: Text(
                      _isReconnecting ? 'กำลังค้นหา...' : 'ค้นหาและเชื่อมต่อซ้ำ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
