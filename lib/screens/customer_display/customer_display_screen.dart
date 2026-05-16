import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state/customer_display_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:async'; // Added
import 'package:intl/date_symbol_data_local.dart'; // Added
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Kept for fallback
import 'package:window_manager/window_manager.dart';
import '../../services/settings_service.dart'; // ✅ Added for multi-machine sync

class CustomerDisplayScreen extends StatefulWidget {
  final String windowId;
  final Map<String, dynamic>? arguments;

  const CustomerDisplayScreen({
    super.key,
    required this.windowId,
    this.arguments,
  });

  @override
  State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
  String? _shopName;
  String? _staticQrBase64;
  String _qrMode = 'dynamic'; // 'dynamic' or 'static'
  String? _bankName; // Added
  String? _bankAccount; // Added
  String? _bankAccountName; // Added

  double _fontSize = 14.0; // ✅ Added default font size

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupWindow();

    // Start Syncing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CustomerDisplayProvider>();
      provider.onReloadSettings = () {
        _loadSettings();
      };
      provider.startSync();
    });
  }

  Future<void> _setupWindow() async {
    if (widget.arguments == null) return;

    try {
      final args = widget.arguments!;

      // แปลงค่าให้ชัวร์ว่าเป็น double
      final double x = (args['x'] is int)
          ? (args['x'] as int).toDouble()
          : (args['x'] as double? ?? 0.0);
      final double y = (args['y'] is int)
          ? (args['y'] as int).toDouble()
          : (args['y'] as double? ?? 0.0);
      final double w = (args['width'] is int)
          ? (args['width'] as int).toDouble()
          : (args['width'] as double? ?? 1280.0);
      final double h = (args['height'] is int)
          ? (args['height'] as int).toDouble()
          : (args['height'] as double? ?? 720.0);

      await windowManager.ensureInitialized();

      // กำหนด Options พื้นฐาน
      WindowOptions windowOptions = WindowOptions(
        size: Size(w, h),
        center: false,
        skipTaskbar: false,
        titleBarStyle:
            TitleBarStyle.hidden, // ซ่อนหัวหน้าต่างเพื่อให้ Full Screen สวยงาม
      );

      // สำคัญ: ใช้ waitUntilReadyToShow เพื่อลำดับการทำงานที่ถูกต้อง
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        // 1. ย้ายไปตำแหน่งจอที่ต้องการก่อน
        await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));

        // 2. สั่ง Full Screen
        if (args['fullscreen'] == true) {
          // เพิ่ม delay เล็กน้อยเพื่อให้ OS รับรู้การย้ายจอก่อนสั่ง Full Screen
          await Future.delayed(const Duration(milliseconds: 100));
          await windowManager.setFullScreen(true);
        }

        // 3. แสดงผลและโฟกัส
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('⚠️ Error setting up Customer Display Window: $e');
    }
  }

  Future<void> _loadSettings() async {
    // ✅ Step 1: ลองโหลดจาก MySQL ก่อน (แชร์กันทุกเครื่อง)
    final settings = SettingsService();
    await settings.loadSettings();

    // ✅ Step 2: SharedPreferences Fallback (ใช้เมื่อ MySQL ยังไม่ได้ connect หรือเครื่องลูกขนาดเล็ก)
    final prefs = await SharedPreferences.getInstance();

    String? getSetting(String key) =>
        settings.getString(key) ?? prefs.getString(key);

    if (!mounted) return;
    setState(() {
      _shopName = getSetting('shop_name') ?? 'S.Mart POS';
      _staticQrBase64 = getSetting('payment_qr_image_base64');
      _qrMode = getSetting('payment_qr_mode') ?? 'dynamic';
      _bankName = getSetting('bank_name');
      _bankAccountName = getSetting('bank_account_name');
      _bankAccount = getSetting('bank_account');

      final sizeStr = getSetting('customer_display_font_size');
      if (sizeStr != null) {
        _fontSize = double.tryParse(sizeStr) ?? 14.0;
      }
    });

    debugPrint('📱 [CustomerDisplay] Settings loaded: mode=$_qrMode, hasStaticQr=${_staticQrBase64 != null}, bank=$_bankAccount');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<CustomerDisplayProvider>(
        builder: (context, provider, child) {
          return Row(
            children: [
              // ------------------------------------------
              // Left: Item List (60%)
              // ------------------------------------------
              Expanded(
                flex: 7,
                child: _buildLeftSection(provider),
              ),
              // ------------------------------------------
              // Right: Summary & QR (30%)
              // ------------------------------------------
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.blueGrey.shade50,
                  child: Column(
                    children: [
                      // Right Top: Summary (Total, Received, Change)
                      Expanded(
                        flex: 3, // ลดขนาดช่อง (30%)
                        child: _buildRightTopSection(provider),
                      ),
                      // Right Bottom: QR Code
                      Expanded(
                        flex: 7, // ขยายช่อง QR (70%)
                        child: _buildRightBottomSection(provider),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // Left Section: Item List
  // ==========================================
  Widget _buildLeftSection(CustomerDisplayProvider provider) {
    if (provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined,
                size: 100, color: Colors.blue.shade100),
            const SizedBox(height: 20),
            Text(_shopName ?? 'ยินดีต้อนรับ',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const Text('ขอบคุณที่ใช้บริการ',
                style: TextStyle(fontSize: 20, color: Colors.grey)),
          ],
        ),
      );
    }

    // ✅ Use Real-time Font Size if available, else use Local Prefs
    final double effectiveFontSize = provider.fontSize ?? _fontSize;

    // Dynamic padding calculations
    final double headerPadding = effectiveFontSize;
    final double itemVerticalPadding = effectiveFontSize * 0.4;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(headerPadding), // ✅ Dynamic Header Padding
          color: Colors.blue,
          child: Row(
            children: [
              Expanded(
                  child: Text('รายการสินค้า',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: effectiveFontSize,
                          fontWeight: FontWeight.bold))),
              Text('รวม',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: effectiveFontSize,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView.separated(
                key: ValueKey(provider.items.length), // ✅ Force rebuild to scroll when item count changes
                controller: ScrollController(
                  initialScrollOffset: provider.items.length * 1000.0, // ✅ Force to bottom
                ),
                padding: EdgeInsets.all(headerPadding / 2),
                itemCount: provider.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = provider.items[index];
              // ✅ Custom Row for precise spacing control
              return Padding(
                padding: EdgeInsets.symmetric(
                    vertical: itemVerticalPadding, horizontal: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Qty
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] ?? '',
                              style: TextStyle(
                                  fontSize: effectiveFontSize,
                                  fontWeight: FontWeight.w500)),
                          Text(
                              '${item['qty']} x ${NumberFormat('#,##0.00').format(item['price'])}',
                              style: TextStyle(
                                  fontSize: effectiveFontSize * 0.85,
                                  color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Total
                    Text(NumberFormat('#,##0.00').format(item['total']),
                        style: TextStyle(
                            fontSize: effectiveFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ],
                ),
              );
            },
          );
          }),
        ),
      ],
    );
  }

  // ==========================================
  // Right Top: Summary
  // ==========================================
  Widget _buildRightTopSection(CustomerDisplayProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.blue.shade900,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _DigitalClock(), // คืนขนาดใหญ่เดิม
              const SizedBox(height: 15),
              const SizedBox(
                width: 300,
                child: Divider(color: Colors.white24),
              ),
              const SizedBox(height: 15),
              const Text('ยอดชำระ',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 20)), // คืนขนาดเดิม
              Text(
                NumberFormat('#,##0.00').format(provider.total),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 60, // คืนขนาดเดิม
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (provider.state == 'success' || provider.received > 0) ...[
                const SizedBox(
                  width: 300,
                  child: Divider(color: Colors.white24),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('รับเงิน:',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18)), // คืนขนาดเดิม
                          Text(NumberFormat('#,##0.00').format(provider.received),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('เงินทอน:',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18)), // คืนขนาดเดิม
                          Text(NumberFormat('#,##0.00').format(provider.change),
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (provider.state == 'success') ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                              SizedBox(width: 8),
                              Text('ชำระเงินสำเร็จ', style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Right Bottom: QR Code
  // ==========================================
  Widget _buildRightBottomSection(CustomerDisplayProvider provider) {
    Widget qrWidget;
    if (_qrMode == 'static' && _staticQrBase64 != null) {
      qrWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ช่องทางชำระเงินอื่น',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 10),
          Flexible(
            child: Image.memory(
              base64Decode(_staticQrBase64!),
              fit: BoxFit.contain, // จะขยายให้ใหญ่สุดแต่ไม่ล้น
            ),
          ),
        ],
      );
    } else if (_qrMode == 'dynamic' &&
        provider.state == 'payment' &&
        provider.qrData != null) {
      qrWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('สแกนจ่าย PromptPay',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 10),
          Flexible(
            child: AspectRatio(
              aspectRatio: 1, // ทำให้เป็นสี่เหลี่ยมจัตุรัส
              child: QrImageView(
                data: provider.qrData!,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    } else {
      qrWidget = const Opacity(
          opacity: 0.1, child: Icon(Icons.qr_code_2, size: 100));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Column(
        children: [
          // ส่วน QR ขยายให้ใหญ่สุดตามพื้นที่ที่เหลือ
          Expanded(child: Center(child: qrWidget)),

          // Bank Info Section
          if (_bankName != null &&
              _bankName!.isNotEmpty &&
              _bankAccount != null &&
              _bankAccount!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(indent: 20, endIndent: 20, height: 20),
            const Text('หรือโอนเงินผ่านบัญชี',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(_bankName!,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            if (_bankAccountName != null && _bankAccountName!.isNotEmpty)
              Text(_bankAccountName!,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54)),
            Text(_bankAccount!,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.black87)),
          ]
        ],
      ),
    );
  }
}

// ✅ Real-time Clock Widget for Customer Display
class _DigitalClock extends StatefulWidget {
  const _DigitalClock();

  @override
  State<_DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<_DigitalClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          DateFormat('EEEE d MMMM yyyy', 'th').format(_now),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16, // คืนขนาดเดิม
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          DateFormat('HH:mm:ss', 'th').format(_now),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28, // คืนขนาดเดิม
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
