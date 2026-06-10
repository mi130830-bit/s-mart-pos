import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../services/telegram_service.dart';
import '../../services/firestore_rest_service.dart';
import '../../services/logger_service.dart';

class ConnectionSettingsState {
  final bool isLoading;
  final bool telegramEnabled;
  final bool tgNotifyPayment;
  final bool tgNotifyDebt;
  final bool tgNotifyDeleteBill;
  final bool tgNotifyLowStock;
  final bool tgNotifyDelivery;
  final bool tgNotifyStockAdjust;
  final bool tgNotifyAppOpen;
  final bool tgNotifyHourlySales;

  const ConnectionSettingsState({
    this.isLoading = true,
    this.telegramEnabled = false,
    this.tgNotifyPayment = true,
    this.tgNotifyDebt = true,
    this.tgNotifyDeleteBill = true,
    this.tgNotifyLowStock = false,
    this.tgNotifyDelivery = true,
    this.tgNotifyStockAdjust = true,
    this.tgNotifyAppOpen = false,
    this.tgNotifyHourlySales = false,
  });

  ConnectionSettingsState copyWith({
    bool? isLoading,
    bool? telegramEnabled,
    bool? tgNotifyPayment,
    bool? tgNotifyDebt,
    bool? tgNotifyDeleteBill,
    bool? tgNotifyLowStock,
    bool? tgNotifyDelivery,
    bool? tgNotifyStockAdjust,
    bool? tgNotifyAppOpen,
    bool? tgNotifyHourlySales,
  }) {
    return ConnectionSettingsState(
      isLoading: isLoading ?? this.isLoading,
      telegramEnabled: telegramEnabled ?? this.telegramEnabled,
      tgNotifyPayment: tgNotifyPayment ?? this.tgNotifyPayment,
      tgNotifyDebt: tgNotifyDebt ?? this.tgNotifyDebt,
      tgNotifyDeleteBill: tgNotifyDeleteBill ?? this.tgNotifyDeleteBill,
      tgNotifyLowStock: tgNotifyLowStock ?? this.tgNotifyLowStock,
      tgNotifyDelivery: tgNotifyDelivery ?? this.tgNotifyDelivery,
      tgNotifyStockAdjust: tgNotifyStockAdjust ?? this.tgNotifyStockAdjust,
      tgNotifyAppOpen: tgNotifyAppOpen ?? this.tgNotifyAppOpen,
      tgNotifyHourlySales: tgNotifyHourlySales ?? this.tgNotifyHourlySales,
    );
  }
}

class ConnectionSettingsNotifier extends AutoDisposeNotifier<ConnectionSettingsState> {
  final SettingsService _settings = SettingsService();

  // Telegram
  late final TextEditingController telegramTokenCtrl;
  late final TextEditingController telegramChatIdCtrl;

  // Firebase
  late final TextEditingController firebaseEmailCtrl;
  late final TextEditingController firebasePasswordCtrl;

  // AI
  late final TextEditingController geminiApiKeyCtrl;

  // API Middleware
  late final TextEditingController apiUrlCtrl;

  // Delivery / GPS
  late final TextEditingController shopLatCtrl;
  late final TextEditingController shopLngCtrl;

  @override
  ConnectionSettingsState build() {
    telegramTokenCtrl = TextEditingController(text: _settings.telegramToken);
    telegramChatIdCtrl = TextEditingController(text: _settings.telegramChatId);
    firebaseEmailCtrl = TextEditingController(text: _settings.firebaseAuthEmail);
    firebasePasswordCtrl = TextEditingController(text: _settings.firebaseAuthPassword);
    geminiApiKeyCtrl = TextEditingController(text: _settings.geminiApiKey);
    apiUrlCtrl = TextEditingController(text: _settings.apiUrl);
    shopLatCtrl = TextEditingController(text: _settings.shopLatitude != 0.0 ? _settings.shopLatitude.toString() : '16.160189');
    shopLngCtrl = TextEditingController(text: _settings.shopLongitude != 0.0 ? _settings.shopLongitude.toString() : '100.802307');

    ref.onDispose(() {
      telegramTokenCtrl.dispose();
      telegramChatIdCtrl.dispose();
      firebaseEmailCtrl.dispose();
      firebasePasswordCtrl.dispose();
      geminiApiKeyCtrl.dispose();
      apiUrlCtrl.dispose();
      shopLatCtrl.dispose();
      shopLngCtrl.dispose();
    });

    return ConnectionSettingsState(
      isLoading: false,
      telegramEnabled: _settings.telegramEnabled,
      tgNotifyPayment: _settings.telegramNotifyPayment,
      tgNotifyDebt: _settings.telegramNotifyDebt,
      tgNotifyDeleteBill: _settings.telegramNotifyDeleteBill,
      tgNotifyLowStock: _settings.telegramNotifyLowStock,
      tgNotifyDelivery: _settings.telegramNotifyDelivery,
      tgNotifyStockAdjust: _settings.telegramNotifyStockAdjust,
      tgNotifyAppOpen: _settings.telegramNotifyAppOpen,
      tgNotifyHourlySales: _settings.telegramNotifyHourlySales,
    );
  }

  void loadSettings() {
    state = state.copyWith(isLoading: true);

    state = state.copyWith(
      telegramEnabled: _settings.telegramEnabled,
      tgNotifyPayment: _settings.telegramNotifyPayment,
      tgNotifyDebt: _settings.telegramNotifyDebt,
      tgNotifyDeleteBill: _settings.telegramNotifyDeleteBill,
      tgNotifyLowStock: _settings.telegramNotifyLowStock,
      tgNotifyDelivery: _settings.telegramNotifyDelivery,
      tgNotifyStockAdjust: _settings.telegramNotifyStockAdjust,
      tgNotifyAppOpen: _settings.telegramNotifyAppOpen,
      tgNotifyHourlySales: _settings.telegramNotifyHourlySales,
    );

    telegramTokenCtrl.text = _settings.telegramToken;
    telegramChatIdCtrl.text = _settings.telegramChatId;

    firebaseEmailCtrl.text = _settings.firebaseAuthEmail;
    firebasePasswordCtrl.text = _settings.firebaseAuthPassword;

    geminiApiKeyCtrl.text = _settings.geminiApiKey;

    apiUrlCtrl.text = _settings.apiUrl;

    shopLatCtrl.text = _settings.shopLatitude != 0.0 ? _settings.shopLatitude.toString() : '16.160189';
    shopLngCtrl.text = _settings.shopLongitude != 0.0 ? _settings.shopLongitude.toString() : '100.802307';

    state = state.copyWith(isLoading: false);
  }

  Future<void> saveSettings() async {
    await _settings.set('telegram_enabled', state.telegramEnabled);
    await _settings.set('telegram_token', telegramTokenCtrl.text);
    await _settings.set('telegram_chat_id', telegramChatIdCtrl.text);
    await _settings.set('telegram_notify_payment', state.tgNotifyPayment);
    await _settings.set('telegram_notify_debt', state.tgNotifyDebt);
    await _settings.set('telegram_notify_delete_bill', state.tgNotifyDeleteBill);
    await _settings.set('telegram_notify_low_stock', state.tgNotifyLowStock);
    await _settings.set('telegram_notify_delivery', state.tgNotifyDelivery);
    await _settings.set('telegram_notify_stock_adjust', state.tgNotifyStockAdjust);
    await _settings.set('telegram_notify_app_open', state.tgNotifyAppOpen);
    await _settings.set('telegram_notify_hourly_sales', state.tgNotifyHourlySales);

    await _settings.set('firebase_auth_email', firebaseEmailCtrl.text);
    await _settings.set('firebase_auth_password', firebasePasswordCtrl.text);

    await _settings.set('gemini_api_key', geminiApiKeyCtrl.text);

    await _settings.set('api_url', apiUrlCtrl.text.trim());

    final lat = double.tryParse(shopLatCtrl.text.trim()) ?? 0.0;
    final lng = double.tryParse(shopLngCtrl.text.trim()) ?? 0.0;
    await _settings.set('shop_latitude', lat.toString());
    await _settings.set('shop_longitude', lng.toString());

    // ✅ Sync พิกัดร้านไปยัง Firestore config/mobile_app
    // เพื่อให้ S-Link ทุกเครื่องดึงพิกัดสำหรับระบบลงเวลาได้อัตโนมัติ
    if (lat != 0.0 && lng != 0.0) {
      FirestoreRestService().setDocument('config', 'mobile_app', {
        'store_lat': lat,
        'store_lng': lng,
        'max_checkin_distance': 100.0,
      }).then((_) {
        LoggerService.info('Settings', 'Synced store GPS to Firestore: $lat, $lng');
      }).catchError((e) {
        LoggerService.warning('Settings', 'Failed to sync store GPS to Firestore: $e');
      });
    }
  }

  void updateTelegramEnabled(bool val) {
    state = state.copyWith(telegramEnabled: val);
    saveSettings(); // Auto save
  }

  void updateNotifySetting(String key, bool val) {
    switch (key) {
      case 'payment':
        state = state.copyWith(tgNotifyPayment: val);
        break;
      case 'debt':
        state = state.copyWith(tgNotifyDebt: val);
        break;
      case 'deleteBill':
        state = state.copyWith(tgNotifyDeleteBill: val);
        break;
      case 'lowStock':
        state = state.copyWith(tgNotifyLowStock: val);
        break;
      case 'delivery':
        state = state.copyWith(tgNotifyDelivery: val);
        break;
      case 'stockAdjust':
        state = state.copyWith(tgNotifyStockAdjust: val);
        break;
      case 'appOpen':
        state = state.copyWith(tgNotifyAppOpen: val);
        break;
      case 'hourlySales':
        state = state.copyWith(tgNotifyHourlySales: val);
        break;
    }
    saveSettings(); // Auto save
  }

  // Telegram API Test
  Future<bool> testTelegramToken() async {
    final token = telegramTokenCtrl.text.trim();
    final chatId = telegramChatIdCtrl.text.trim();
    if (token.isEmpty || chatId.isEmpty) return false;
    return await TelegramService().testToken(token, chatId);
  }

  // Firebase API Test
  Future<String?> testFirebaseConnection() async {
    final email = firebaseEmailCtrl.text.trim();
    final password = firebasePasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return 'กรุณากรอก Email และ Password ให้ครบถ้วน';
    
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  // API Middleware Test
  Future<String?> testApiConnection() async {
    final urlStr = apiUrlCtrl.text.trim();
    if (urlStr.isEmpty) return 'กรุณากรอก API URL';
    
    try {
      final uri = Uri.parse(urlStr);
      final healthUri = uri.replace(path: '/health');
      final response = await http.get(healthUri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return null; // success
      } else {
        return 'พบ Server แต่สถานะไม่ถูกต้อง (${response.statusCode})';
      }
    } catch (e) {
      return e.toString();
    }
  }

}

final connectionSettingsProvider = NotifierProvider.autoDispose<ConnectionSettingsNotifier, ConnectionSettingsState>(
  ConnectionSettingsNotifier.new,
);
