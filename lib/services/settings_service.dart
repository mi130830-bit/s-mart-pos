import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mysql_service.dart';
import 'local_settings_service.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  final Map<String, String> _memoryCache = {};
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('⚠️ [SettingsService] Listener error: $e');
      }
    }
  }

  /// ✅ Pre-load essential settings from SharedPreferences (for early startup/login)
  /// This allows API URL to be available even before MySQL connects.
  Future<void> preLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load only critical connectivity keys for now
      final keys = ['api_url', 'shop_name', 'promptpay_id'];
      for (final key in keys) {
        final val = prefs.getString(key);
        if (val != null) {
          _memoryCache[key] = val;
        }
      }

      // ✅ โหลด Local Override ของ API URL และ Bills Path (เครื่องใครเครื่องมัน)
      // ใช้ key พิเศษ __ เพื่อแยกจาก Global MySQL keys
      final localApiUrl = prefs.getString('local_api_url');
      if (localApiUrl != null && localApiUrl.isNotEmpty) {
        _memoryCache['__local_api_url'] = localApiUrl;
        debugPrint('⚡ [SettingsService] Local API URL override loaded: $localApiUrl');
      }

      final localBillsPath = prefs.getString('local_bills_base_path');
      if (localBillsPath != null && localBillsPath.isNotEmpty) {
        _memoryCache['__local_bills_base_path'] = localBillsPath;
        debugPrint('⚡ [SettingsService] Local bills path override loaded: $localBillsPath');
      }

      debugPrint('⚡ [SettingsService] Pre-loaded ${_memoryCache.length} critical settings from Prefs.');
    } catch (e) {
      debugPrint('⚠️ [SettingsService] Pre-load failed: $e');
    } finally {
      _notifyListeners();
    }
  }

  /// Load all settings from MySQL into memory
  /// Should be called after DatabaseInitializer
  Future<void> loadSettings() async {
    try {
      final db = MySQLService();
      if (!db.isConnected()) {
        debugPrint(
            '⚠️ [SettingsService] Database not connected. Using local fallbacks if available.');
        return;
      }

      final results = await db
          .query('SELECT setting_key, setting_value FROM system_settings');
      _memoryCache.clear();

      final prefs = await SharedPreferences.getInstance(); // Get Prefs

      for (final row in results) {
        final key = row['setting_key'] as String;
        final value = row['setting_value'] as String?;
        if (value != null) {
          // ✅ Cleanup: Remove legacy/invalid printer paths from previous defaults
          // Only target paths starting with \\ms which are known bad defaults
          if (value.startsWith(r'\\ms')) {
            debugPrint(
                '🧹 [SettingsService] Cleaning up invalid legacy value: $key = $value');
            // Remove from DB async (fire and forget)
            db.execute('DELETE FROM system_settings WHERE setting_key = :k',
                {'k': key});
            continue; // Skip loading this value
          }

          _memoryCache[key] = value;
          // ✅ Sync to SharedPreferences immediately for Customer Display
          await prefs.setString(key, value);
        }
      }

      debugPrint(
          '✅ [SettingsService] Loaded ${_memoryCache.length} settings from DB and synced to Prefs.');
    } catch (e) {
      debugPrint('❌ [SettingsService] Failed to load settings: $e');
    } finally {
      _notifyListeners(); // ✅ Notify anyone waiting for settings
    }
  }

  /// Get String
  String? getString(String key) {
    return _memoryCache[key];
  }

  /// Get Bool
  bool getBool(String key, {bool defaultValue = false}) {
    final val = _memoryCache[key];
    if (val == null) return defaultValue;
    return val.toLowerCase() == 'true' || val == '1';
  }

  /// Get Int
  int getInt(String key, {int defaultValue = 0}) {
    final val = _memoryCache[key];
    if (val == null) return defaultValue;
    return int.tryParse(val) ?? defaultValue;
  }

  // Auto-Print Settings
  bool get autoPrintReceipt =>
      getBool('auto_print_receipt', defaultValue: false);
  set autoPrintReceipt(bool value) => set('auto_print_receipt', value);

  bool get autoPrintDeliveryNote =>
      getBool('auto_print_delivery_note', defaultValue: false);
  set autoPrintDeliveryNote(bool value) =>
      set('auto_print_delivery_note', value);

  // --- Shop Info (Global) ---
  String get shopName => getString('shop_name') ?? 'ร้านส.บริการ ท่าข้าม';
  set shopName(String value) => set('shop_name', value);

  String get shopAddress => getString('shop_address') ?? '';
  set shopAddress(String value) => set('shop_address', value);

  String get shopShortAddress => getString('shop_short_address') ?? '';
  set shopShortAddress(String value) => set('shop_short_address', value);

  String get shopShortName => getString('shop_short_name') ?? '';
  set shopShortName(String value) => set('shop_short_name', value);

  String get shopPhone => getString('shop_phone') ?? '';
  set shopPhone(String value) => set('shop_phone', value);

  String get shopTaxId => getString('shop_tax_id') ?? '';
  set shopTaxId(String value) => set('shop_tax_id', value);

  String get shopBranch => getString('shop_branch') ?? 'สำนักงานใหญ่';
  set shopBranch(String value) => set('shop_branch', value);

  String get shopFooter => getString('shop_footer') ?? 'ขอบคุณที่ใช้บริการ';
  set shopFooter(String value) => set('shop_footer', value);

  String get shopLogoPath => getString('shop_logo_path') ?? '';
  set shopLogoPath(String value) => set('shop_logo_path', value);

  // --- Delivery / GPS Settings ---
  double get shopLatitude =>
      double.tryParse(getString('shop_latitude') ?? '0') ?? 0.0;
  set shopLatitude(double value) => set('shop_latitude', value.toString());

  double get shopLongitude =>
      double.tryParse(getString('shop_longitude') ?? '0') ?? 0.0;
  set shopLongitude(double value) => set('shop_longitude', value.toString());

  double get fuelCostPerKm =>
      double.tryParse(getString('fuel_cost_per_km') ?? '3.0') ?? 3.0;
  set fuelCostPerKm(double value) => set('fuel_cost_per_km', value.toString());

  // --- Policies & Rates (Global) ---
  double get vatRate => double.tryParse(getString('vat_rate') ?? '7.0') ?? 7.0;
  set vatRate(double value) => set('vat_rate', value.toString());

  double get memberDiscountRate =>
      double.tryParse(getString('member_discount_rate') ?? '0.0') ?? 0.0;
  set memberDiscountRate(double value) =>
      set('member_discount_rate', value.toString());

  bool get allowNegativeStock =>
      getBool('allow_negative_stock', defaultValue: true);
  set allowNegativeStock(bool value) => set('allow_negative_stock', value);

  // --- Payment (Global) ---
  String get promptPayId => getString('promptpay_id') ?? '';
  set promptPayId(String value) => set('promptpay_id', value);

  // Rounding Mode: 'none', 'up', 'down', 'auto'
  String get roundingMode => getString('rounding_mode') ?? 'none';
  set roundingMode(String value) => set('rounding_mode', value);

  // --- Item Discount Settings ---
  // Mode: 'per_item' (ต่อรายการ), 'per_piece' (ต่อชิ้น)
  String get itemDiscountMode => getString('item_discount_mode') ?? 'per_item';
  set itemDiscountMode(String value) => set('item_discount_mode', value);

  // --- Telegram Settings (Global) ---
  bool get telegramEnabled => getBool('telegram_enabled');
  set telegramEnabled(bool value) => set('telegram_enabled', value);

  String get telegramToken => getString('telegram_token') ?? '';
  set telegramToken(String value) => set('telegram_token', value);

  String get telegramChatId => getString('telegram_chat_id') ?? '';
  set telegramChatId(String value) => set('telegram_chat_id', value);

  bool get telegramNotifyPayment =>
      getBool('telegram_notify_payment', defaultValue: true);
  set telegramNotifyPayment(bool value) =>
      set('telegram_notify_payment', value);

  bool get telegramNotifyDebt =>
      getBool('telegram_notify_debt', defaultValue: true);
  set telegramNotifyDebt(bool value) => set('telegram_notify_debt', value);

  bool get telegramNotifyDeleteBill =>
      getBool('telegram_notify_delete_bill', defaultValue: true);
  set telegramNotifyDeleteBill(bool value) =>
      set('telegram_notify_delete_bill', value);

  bool get telegramNotifyLowStock =>
      getBool('telegram_notify_low_stock', defaultValue: false);
  set telegramNotifyLowStock(bool value) =>
      set('telegram_notify_low_stock', value);

  bool get telegramNotifyDelivery =>
      getBool('telegram_notify_delivery', defaultValue: true);
  set telegramNotifyDelivery(bool value) =>
      set('telegram_notify_delivery', value);

  bool get telegramNotifyStockAdjust =>
      getBool('telegram_notify_stock_adjust', defaultValue: true);
  set telegramNotifyStockAdjust(bool value) =>
      set('telegram_notify_stock_adjust', value);

  bool get telegramNotifyAppOpen =>
      getBool('telegram_notify_app_open', defaultValue: false);
  set telegramNotifyAppOpen(bool value) =>
      set('telegram_notify_app_open', value);

  bool get telegramNotifyHourlySales =>
      getBool('telegram_notify_hourly_sales', defaultValue: false);
  set telegramNotifyHourlySales(bool value) =>
      set('telegram_notify_hourly_sales', value);

  // --- Firebase Settings (Global) ---
  String get firebaseAuthEmail => getString('firebase_auth_email') ?? '';
  set firebaseAuthEmail(String value) => set('firebase_auth_email', value);

  String get firebaseAuthPassword => getString('firebase_auth_password') ?? '';
  set firebaseAuthPassword(String value) =>
      set('firebase_auth_password', value);

  // --- AI Settings (Global) ---
  String get geminiApiKey => getString('gemini_api_key') ?? '';
  set geminiApiKey(String value) => set('gemini_api_key', value);

  // --- Google Drive Settings ---
  String get gdriveClientId => getString('gdrive_client_id') ?? '';
  set gdriveClientId(String value) => set('gdrive_client_id', value);

  String get gdriveClientSecret => getString('gdrive_client_secret') ?? '';
  set gdriveClientSecret(String value) => set('gdrive_client_secret', value);

  // --- Line OA Settings ---
  String get lineChannelAccessToken =>
      getString('line_channel_access_token') ?? '';
  set lineChannelAccessToken(String value) =>
      set('line_channel_access_token', value);

  // --- API Middleware Settings ---
  /// API URL สำหรับเครื่องนี้
  /// อ่าน Local Override (SharedPreferences) ก่อน ถ้าไม่มีค่อย Fallback ไป MySQL cache
  /// ทำให้แต่ละเครื่องใน LAN มี URL ของตัวเองได้ โดยไม่เขียนทับกัน
  String get apiUrl {
    // Local Override ถูกเซตไว้แล้วใน preLoad() ถ้ามี
    final localOverride = _memoryCache['__local_api_url'];
    if (localOverride != null && localOverride.isNotEmpty) {
      return _normalizeApiUrl(localOverride);
    }
    // Fallback: ค่าจาก MySQL (Global default)
    return _normalizeApiUrl(
        _memoryCache['api_url'] ?? 'http://localhost:8080/api/v1');
  }

  String _normalizeApiUrl(String url) {
    if (!url.endsWith('/api/v1') && !url.contains('/api/v')) {
      url = url.endsWith('/') ? '${url}api/v1' : '$url/api/v1';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  set apiUrl(String value) => set('api_url', value);

  /// ✅ Sync API URL กับ host ใหม่ที่ mDNS/scanner หาได้
  /// บันทึก **เฉพาะใน SharedPreferences ของเครื่องนี้** ไม่แตะ MySQL
  /// เพื่อป้องกันเครื่องลูกไป overwrite ค่า Global ของทั้งร้าน
  Future<void> syncApiUrlWithHost(String newHost) async {
    try {
      final String currentUrl =
          _memoryCache['api_url'] ?? 'http://localhost:8080/api/v1';
      final Uri? uri = Uri.tryParse(currentUrl);
      if (uri != null) {
        final newUri = uri.replace(host: newHost);
        final newUrl = newUri.toString();
        // เขียนลง Local memory cache (key พิเศษ ไม่ใช่ key ของ MySQL)
        _memoryCache['__local_api_url'] = newUrl;
        // เขียนลง SharedPreferences ของเครื่องนี้เท่านั้น
        await LocalSettingsService().setLocalApiUrl(newUrl);
        debugPrint(
            '🔄 [SettingsService] Local API URL synced to host: $newHost (MySQL untouched)');
      }
    } catch (e) {
      debugPrint('⚠️ [SettingsService] syncApiUrlWithHost failed: $e');
    }
  }

  /// Path สำหรับเก็บไฟล์ภาพบิล — LOCAL ONLY (เครื่องใครเครื่องมัน)
  /// เพราะแต่ละเครื่องอาจติดตั้งโปรแกรมในไดรฟ์ต่างกัน
  /// อ่านจาก LocalSettingsService → ถ้าไม่มีค่า Fallback ไปใช้ path เดิม
  String get billsBasePath {
    // ใช้ค่า Cached จาก preLoad ที่โหลดใน __local_bills_base_path
    return _memoryCache['__local_bills_base_path'] ??
        'C:/pos_desktop/backend/public/bills';
  }

  set billsBasePath(String value) {
    _memoryCache['__local_bills_base_path'] = value;
    // บันทึกลง LocalSettingsService (SharedPreferences) เท่านั้น
    LocalSettingsService().setBillsBasePath(value);
  }

  // --- Point System Settings (Global) ---
  bool get pointEnabled => getBool('point_enabled', defaultValue: false);
  set pointEnabled(bool value) => set('point_enabled', value);

  String get pointCalcType => getString('point_calc_type') ?? 'price';
  set pointCalcType(String value) => set('point_calc_type', value);

  double get pointPriceRate =>
      double.tryParse(getString('point_price_rate') ?? '100') ?? 100.0;
  set pointPriceRate(double value) => set('point_price_rate', value);

  double get pointRedemptionRate =>
      double.tryParse(getString('point_redemption_rate') ?? '10') ?? 10.0;
  set pointRedemptionRate(double value) => set('point_redemption_rate', value);

  bool get pointAfterDiscount =>
      getBool('point_after_discount', defaultValue: false);
  set pointAfterDiscount(bool value) => set('point_after_discount', value);

  List<int> get pointExcludedProductIds {
    final str = getString('point_excluded_product_ids');
    if (str == null || str.isEmpty) return [];
    return str
        .split(',')
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e != 0)
        .toList();
  }

  set pointExcludedProductIds(List<int> ids) {
    set('point_excluded_product_ids', ids.join(','));
  }

  // --- Bank Transfer Info (Global) ---
  String get bankName => getString('bank_name') ?? '';
  set bankName(String value) => set('bank_name', value);

  String get bankAccount => getString('bank_account') ?? '';
  set bankAccount(String value) => set('bank_account', value);

  String get bankAccountName => getString('bank_account_name') ?? '';
  set bankAccountName(String value) => set('bank_account_name', value);

  /// Set Value (String, Bool, Int)
  /// Updates memory, DB immediately, and SharedPreferences (for Multi-Window sync)
  Future<void> set(String key, dynamic value) async {
    final String strValue = value.toString();
    _memoryCache[key] = strValue;

    // 1. Sync to SharedPreferences (for Customer Display / Other Windows)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, strValue);
    } catch (e) {
      debugPrint('⚠️ [SettingsService] Failed to sync to Prefs: $e');
    }

    // 2. Save to MySQL
    try {
      final db = MySQLService();
      // Using UPSERT (INSERT ... ON DUPLICATE KEY UPDATE)
      await db.execute(
        'INSERT INTO system_settings (setting_key, setting_value) VALUES (:key, :val) ON DUPLICATE KEY UPDATE setting_value = :val',
        {'key': key, 'val': strValue},
      );
      // Also notify listeners if we add ChangeNotifier later
    } catch (e) {
      debugPrint('❌ [SettingsService] Failed to save setting $key: $e');
      rethrow; // ✅ Rethrow to let UI know
    }

    _notifyListeners(); // ✅ Notify listeners of change
  }

  /// Remove setting
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final db = MySQLService();
      await db.execute(
          'DELETE FROM system_settings WHERE setting_key = :key', {'key': key});
    } catch (e) {
      debugPrint('❌ [SettingsService] Failed to remove setting $key: $e');
    }
  }

  // --- Security Settings ---
  bool get requireAdminForVoid =>
      getBool('require_admin_for_void', defaultValue: false);
  set requireAdminForVoid(bool value) => set('require_admin_for_void', value);

  bool get requireAdminForStockAdjust =>
      getBool('require_admin_for_stock_adjust', defaultValue: false);
  set requireAdminForStockAdjust(bool value) =>
      set('require_admin_for_stock_adjust', value);

  String get adminPin => getString('admin_pin') ?? '1234';
  set adminPin(String value) => set('admin_pin', value);

  // --- Warehouse Settings ---
  bool get enableWarehouseAutoTag =>
      getBool('enable_warehouse_auto_tag', defaultValue: true);
  set enableWarehouseAutoTag(bool value) =>
      set('enable_warehouse_auto_tag', value);

  // --- Customer Display Settings ---
  double get customerDisplayFontSize =>
      double.tryParse(getString('customer_display_font_size') ?? '14.0') ??
      14.0;
  set customerDisplayFontSize(double value) =>
      set('customer_display_font_size', value.toString());
}
