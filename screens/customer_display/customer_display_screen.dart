import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state/customer_display_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupWindow(); // ✅ Setup Window Position

    // Start Syncing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerDisplayProvider>().startSync();
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shop_name') ?? 'S.Mart POS';
      _staticQrBase64 = prefs.getString('static_qr_base64');
    });
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
                        flex: 1,
                        child: _buildRightTopSection(provider),
                      ),
                      // Right Bottom: QR Code
                      Expanded(
                        flex: 1,
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.blue,
          child: const Row(
            children: [
              Expanded(
                  child: Text('รายการสินค้า',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20, // Reduced from 24
                          fontWeight: FontWeight.bold))),
              Text('รวม',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Reduced from 24
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: provider.items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return ListTile(
                title: Text(item['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500)), // Reduced from 24
                subtitle: Text(
                    '${item['qty']} x ${NumberFormat('#,##0.00').format(item['price'])}',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700)), // Reduced from 20
                trailing: Text(NumberFormat('#,##0.00').format(item['total']),
                    style: const TextStyle(
                        fontSize: 20, // Reduced from 24
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Right Top: Summary
  // ==========================================
  Widget _buildRightTopSection(CustomerDisplayProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.blue.shade900,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FittedBox(
            child: Text('ยอดชำระ',
                style: TextStyle(
                    color: Colors.white70, fontSize: 20)), // Reduced from 24
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat('#,##0.00').format(provider.total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 60, // Reduced from 80
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10), // Reduced height from 20 to 10
          if (provider.state == 'success' || provider.received > 0) ...[
            const Divider(color: Colors.white24),
            Expanded(
              // Wrap list in Expanded + ListView/SingleChildScrollView if needed, but FittedBox is better for fixed layout
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('รับเงิน:',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18)), // Reduced from 22
                        const SizedBox(width: 20),
                        Text(NumberFormat('#,##0.00').format(provider.received),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22, // Reduced from 26
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
                                fontSize: 18)), // Reduced from 22
                        const SizedBox(width: 20),
                        Text(NumberFormat('#,##0.00').format(provider.change),
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 22, // Reduced from 26
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  // ==========================================
  // Right Bottom: QR Code
  // ==========================================
  Widget _buildRightBottomSection(CustomerDisplayProvider provider) {
    if (provider.state == 'success') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 10),
            const Text('ชำระเงินสำเร็จ',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
      );
    }

    if (provider.state == 'payment' && provider.qrData != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('สแกนจ่าย PromptPay',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
            const SizedBox(height: 10),
            QrImageView(
                data: provider.qrData!,
                size: 220,
                backgroundColor: Colors.white),
          ],
        ),
      );
    }

    // Default: Show Static QR if available, else Logo or Empty
    if (_staticQrBase64 != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ช่องทางชำระเงินอื่น',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 10),
            Image.memory(base64Decode(_staticQrBase64!),
                height: 200, fit: BoxFit.contain),
          ],
        ),
      );
    }

    return const Center(
      child: Opacity(
        opacity: 0.1,
        child: Icon(Icons.qr_code_2, size: 100),
      ),
    );
  }
}
