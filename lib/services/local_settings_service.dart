import 'package:shared_preferences/shared_preferences.dart';

// Service for handling local app settings (e.g. Printer config)

class LocalSettingsService {
  static final LocalSettingsService _instance =
      LocalSettingsService._internal();

  factory LocalSettingsService() {
    return _instance;
  }

  LocalSettingsService._internal();

  // Keys for Hardware Settings (Printers) - LOCAL ONLY
  static const String _keyLocalPrinterCashName = 'local_printer_cash_name';
  static const String _keyLocalPrinterCashBillName =
      'local_printer_cash_bill_name';
  static const String _keyLocalPrinterTaxName = 'local_printer_tax_name';
  static const String _keyLocalPrinterDeliveryName =
      'local_printer_delivery_name';
  static const String _keyLocalPrinterBarcodeName =
      'local_printer_barcode_name';

  static const String _keyLocalPaperSizeCash = 'local_printer_cash_paper_size';
  static const String _keyLocalPaperSizeCashBill =
      'local_printer_cash_bill_paper_size';
  static const String _keyLocalPaperSizeDelivery =
      'local_printer_delivery_paper_size';
  static const String _keyLocalPaperSizeBarcode =
      'local_printer_barcode_paper_size';

  // Keys for Drawer - LOCAL ONLY
  static const String _keyLocalDrawerAutoOpen = 'local_drawer_auto_open';
  static const String _keyLocalDrawerPort = 'local_drawer_port';
  static const String _keyLocalDrawerCommand = 'local_drawer_command';
  static const String _keyLocalDrawerUsePrinter = 'local_drawer_use_printer';

  // Keys for Display - LOCAL ONLY
  static const String _keyLocalDarkMode = 'local_dark_mode';
  static const String _keyLocalAutoOpenDisplay =
      'local_auto_open_customer_display';

  // Keys for Path / Network - LOCAL ONLY (แตกต่างตามเครื่อง)
  static const String _keyLocalBillsBasePath = 'local_bills_base_path';
  static const String _keyLocalApiUrl = 'local_api_url';

  // Legacy Keys (For Migration/Fallback)
  static const String _legacyPrinterCashName = 'printer_cash_name';
  static const String _legacyPrinterCashBillName = 'printer_cash_bill_name';
  static const String _legacyPrinterTaxName = 'printer_tax_name';
  static const String _legacyPrinterDeliveryName = 'printer_delivery_name';
  static const String _legacyPrinterBarcodeName = 'printer_barcode_name';

  static const String _keyPrinterBarcodeManualName =
      'printer_barcode_manual_name';

  // --- Generic Helpers ---

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  // ✅ Restored Helper Methods (Used by other services)
  Future<String?> getString(String key, {String? defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  // Helper to get String with Migration
  Future<String?> _getLocalString(String localKey, String legacyKey) async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Try Local Key
    final local = prefs.getString(localKey);
    if (local != null) return local;

    // 2. Fallback to Legacy (Migration)
    final legacy = prefs.getString(legacyKey);
    if (legacy != null) {
      // Optional: Auto-migrate by saving to local immediately?
      // Yes, it's good practice, but let's just read for now to be safe.
      // actually, if we write it back, it persists as local.
      return legacy;
    }
    return null;
  }

  // Helper to set String Locally
  Future<void> _setLocalString(String localKey, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(localKey);
    } else {
      await prefs.setString(localKey, value);
    }
  }

  // --- Getters ---

  Future<String?> getPrinterManualName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterBarcodeManualName);
  }

  Future<String?> getCashPrinterName() async {
    return _getLocalString(_keyLocalPrinterCashName, _legacyPrinterCashName);
  }

  Future<String?> getCashBillPrinterName() async {
    return _getLocalString(
        _keyLocalPrinterCashBillName, _legacyPrinterCashBillName);
  }

  Future<String?> getTaxPrinterName() async {
    return _getLocalString(_keyLocalPrinterTaxName, _legacyPrinterTaxName);
  }

  Future<String?> getDeliveryPrinterName() async {
    return _getLocalString(
        _keyLocalPrinterDeliveryName, _legacyPrinterDeliveryName);
  }

  Future<String?> getBarcodePrinterName() async {
    return _getLocalString(
        _keyLocalPrinterBarcodeName, _legacyPrinterBarcodeName);
  }

  Future<String> getCashPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalPaperSizeCash) ?? '80mm';
  }

  Future<String> getCashBillPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalPaperSizeCashBill) ?? 'A4';
  }

  Future<String> getDeliveryPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalPaperSizeDelivery) ?? 'A5';
  }

  Future<String> getBarcodePaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalPaperSizeBarcode) ?? '40mmx30mm';
  }

  // Drawer
  Future<bool> getDrawerAutoOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocalDrawerAutoOpen) ?? false;
  }

  Future<String> getDrawerPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalDrawerPort) ?? 'COM1';
  }

  Future<String> getDrawerCommand() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalDrawerCommand) ?? '27,112,0,25,250';
  }

  Future<bool> getDrawerUsePrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocalDrawerUsePrinter) ?? true;
  }

  // Display
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocalDarkMode) ?? false;
  }

  Future<bool> getAutoOpenDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocalAutoOpenDisplay) ?? false;
  }

  // Path & Network (Local Override)
  Future<String?> getBillsBasePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalBillsBasePath);
  }

  Future<void> setBillsBasePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalBillsBasePath, path);
  }

  /// ค่า API URL ที่ Override เฉพาะเครื่องนี้
  /// ใช้เมื่อ mDNS/subnet scanner หา host ใหม่ได้ ไม่กระทบเครื่องอื่น
  Future<String?> getLocalApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalApiUrl);
  }

  Future<void> setLocalApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalApiUrl, url);
  }

  Future<void> clearLocalApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocalApiUrl);
  }

  // Auto Print (These are business logic, maybe keep global?
  // User said "Printer Settings" keep changing. Auto-print could be preference per machine.
  // Let's make them local too for consistency.)
  Future<bool> getAutoPrintReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('local_auto_print_receipt') ?? false;
  }

  Future<bool> getAutoPrintDeliveryNote() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('local_auto_print_delivery_note') ?? false;
  }

  // --- Setters (Local Only) ---

  Future<void> setAutoPrintReceipt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('local_auto_print_receipt', value);
  }

  Future<void> setAutoPrintDeliveryNote(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('local_auto_print_delivery_note', value);
  }

  Future<void> setCashPrinterName(String? name) async {
    await _setLocalString(_keyLocalPrinterCashName, name);
  }

  Future<void> setCashBillPrinterName(String? name) async {
    await _setLocalString(_keyLocalPrinterCashBillName, name);
  }

  Future<void> setTaxPrinterName(String? name) async {
    await _setLocalString(_keyLocalPrinterTaxName, name);
  }

  Future<void> setDeliveryPrinterName(String? name) async {
    await _setLocalString(_keyLocalPrinterDeliveryName, name);
  }

  Future<void> setBarcodePrinterName(String? name) async {
    await _setLocalString(_keyLocalPrinterBarcodeName, name);
  }

  Future<void> setCashPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalPaperSizeCash, size);
  }

  Future<void> setCashBillPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalPaperSizeCashBill, size);
  }

  Future<void> setDeliveryPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalPaperSizeDelivery, size);
  }

  Future<void> setBarcodePaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalPaperSizeBarcode, size);
  }

  // Drawer
  Future<void> setDrawerAutoOpen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocalDrawerAutoOpen, value);
  }

  Future<void> setDrawerPort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalDrawerPort, port);
  }

  Future<void> setDrawerCommand(String command) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalDrawerCommand, command);
  }

  Future<void> setDrawerUsePrinter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocalDrawerUsePrinter, value);
  }

  // Display
  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocalDarkMode, value);
  }

  Future<void> setAutoOpenDisplay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocalAutoOpenDisplay, value);
  }
}
