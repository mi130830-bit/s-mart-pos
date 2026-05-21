import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_display_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../../services/settings_service.dart';
import 'widgets/item_list_section.dart';
import 'widgets/summary_section.dart';
import 'widgets/qr_section.dart';

class CustomerDisplayScreen extends ConsumerStatefulWidget {
  final String windowId;
  final Map<String, dynamic>? arguments;

  const CustomerDisplayScreen({
    super.key,
    required this.windowId,
    this.arguments,
  });

  @override
  ConsumerState<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends ConsumerState<CustomerDisplayScreen> {
  String? _shopName;
  String? _staticQrBase64;
  String _qrMode = 'dynamic';
  String? _bankName;
  String? _bankAccount;
  String? _bankAccountName;
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupWindow();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerDisplayProvider(widget.windowId).notifier).onReloadSettings = _loadSettings;
      ref.read(customerDisplayProvider(widget.windowId).notifier).startSync();
    });
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

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    await settings.loadSettings();
    final prefs = await SharedPreferences.getInstance();
    String? getSetting(String key) => settings.getString(key) ?? prefs.getString(key);

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
    debugPrint(
        '📱 [CustomerDisplay] Settings loaded: mode=$_qrMode, hasStaticQr=${_staticQrBase64 != null}, bank=$_bankAccount');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerDisplayProvider(widget.windowId));
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left: Item List (70%)
          Expanded(
            flex: 7,
            child: ItemListSection(
              state: state,
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
                    flex: 3,
                    child: SummarySection(state: state),
                  ),
                  Expanded(
                    flex: 7,
                    child: QrSection(
                      state: state,
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
