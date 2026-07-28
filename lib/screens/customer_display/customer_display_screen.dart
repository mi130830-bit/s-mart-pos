import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'customer_display_repository.dart';
import 'customer_display_provider.dart';
import 'widgets/item_list_section.dart';
import 'widgets/summary_section.dart';
import 'widgets/qr_section.dart';

class CustomerDisplayScreen extends StatefulWidget {
  final String windowId;
  final Map<String, dynamic>? arguments;
  final CustomerDisplayRepository repository;

  const CustomerDisplayScreen({
    super.key,
    required this.windowId,
    required this.repository,
    this.arguments,
  });

  @override
  State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
  // ────── Display State (อัปเดตจาก IPC stream โดยตรง) ──────
  CustomerDisplayMode _mode = CustomerDisplayMode.idle;
  List<Map<String, dynamic>> _items = [];
  double _total = 0.0;
  double _received = 0.0;
  double _change = 0.0;
  String? _qrData;
  double _qrAmount = 0.0;

  // ────── Settings (โหลดจาก SharedPreferences) ──────
  String? _shopName;
  String? _staticQrBase64;
  String _qrMode = 'dynamic';
  String? _bankName;
  String? _bankAccount;
  String? _bankAccountName;
  double _fontSize = 14.0;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  CustomerDisplayState get _state => CustomerDisplayState(
        mode: _mode,
        items: _items,
        total: _total,
        received: _received,
        change: _change,
        qrData: _qrData,
        qrAmount: _qrAmount,
      );

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupWindow();

    // ✅ Subscribe โดยตรงกับ repository stream — ไม่ผ่าน Provider
    _subscription = widget.repository.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleUpdate(Map<String, dynamic> data) {
    debugPrint('🖥️ [CustomerDisplay] Update received: ${data['state']}');

    // ────── reload_settings command ──────
    if (data['action'] == 'reloadSettings') {
      _loadSettings();
      return;
    }

    // ────── parse state ──────
    final stateStr = data['state'] as String? ?? 'idle';
    CustomerDisplayMode newMode;
    switch (stateStr) {
      case 'payment':
        newMode = CustomerDisplayMode.payment;
        break;
      case 'success':
        newMode = CustomerDisplayMode.success;
        break;
      case 'active':
        newMode = CustomerDisplayMode.cart;
        break;
      default:
        newMode = CustomerDisplayMode.idle;
        break;
    }

    // ────── parse items ──────
    List<Map<String, dynamic>> newItems = [];
    if (data['items'] != null) {
      newItems = List<Map<String, dynamic>>.from(
        (data['items'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }

    if (!mounted) return;
    setState(() {
      _mode = newMode;
      _items = newItems;
      _total = (data['total'] as num?)?.toDouble() ?? 0.0;
      _received = (data['received'] as num?)?.toDouble() ?? 0.0;
      _change = (data['change'] as num?)?.toDouble() ?? 0.0;
      _qrAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      _qrData = data['qrData'] as String?;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // cross-process safe

    if (!mounted) return;
    setState(() {
      _shopName = prefs.getString('shop_name') ?? 'S.Mart POS';
      _staticQrBase64 = prefs.getString('payment_qr_image_base64');
      _qrMode = prefs.getString('payment_qr_mode') ?? 'dynamic';
      _bankName = prefs.getString('bank_name');
      _bankAccountName = prefs.getString('bank_account_name');
      _bankAccount = prefs.getString('bank_account');
      final sizeStr = prefs.getString('customer_display_font_size');
      if (sizeStr != null) {
        _fontSize = double.tryParse(sizeStr) ?? 14.0;
      }
    });
    debugPrint('📱 [CustomerDisplay] Settings loaded: fontSize=$_fontSize, shop=$_shopName');
  }

  Future<void> _setupWindow() async {
    if (widget.arguments == null) return;
    try {
      final args = widget.arguments!;
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
      WindowOptions windowOptions = WindowOptions(
        size: Size(w, h),
        center: false,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));
        if (args['fullscreen'] == true) {
          await Future.delayed(const Duration(milliseconds: 100));
          await windowManager.setFullScreen(true);
        }
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('⚠️ Error setting up Customer Display Window: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left: Item List (70%)
          Expanded(
            flex: 7,
            child: ItemListSection(
              state: _state,
              shopName: _shopName,
              fontSize: _fontSize,
            ),
          ),
          // Right: Summary + QR (30%)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.blueGrey.shade50,
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: SummarySection(state: _state),
                  ),
                  Expanded(
                    flex: 6,
                    child: QrSection(
                      state: _state,
                      qrMode: _qrMode,
                      staticQrBase64: _staticQrBase64,
                      bankName: _bankName,
                      bankAccount: _bankAccount,
                      bankAccountName: _bankAccountName,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
