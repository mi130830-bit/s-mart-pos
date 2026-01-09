import 'package:shared_preferences/shared_preferences.dart';

// Service for handling local app settings (e.g. Printer config)

class LocalSettingsService {
  static final LocalSettingsService _instance =
      LocalSettingsService._internal();

  factory LocalSettingsService() {
    return _instance;
  }

  LocalSettingsService._internal();

  // Keys for Hardware Settings (Printers)
  static const String _keyPrinterCashName = 'printer_cash_name';
  static const String _keyPrinterCashBillName = 'printer_cash_bill_name'; // New
  static const String _keyPrinterTaxName = 'printer_tax_name';
  static const String _keyPrinterDeliveryName = 'printer_delivery_name';
  static const String _keyPrinterBarcodeName = 'printer_barcode_name';

  static const String _keyPaperSizeCash = 'printer_cash_paper_size';
  static const String _keyPaperSizeCashBill =
      'printer_cash_bill_paper_size'; // New
  static const String _keyPaperSizeDelivery = 'printer_delivery_paper_size';
  static const String _keyPaperSizeBarcode = 'printer_barcode_paper_size';

  // Keys for Drawer
  static const String _keyDrawerAutoOpen = 'drawer_auto_open';
  static const String _keyDrawerPort = 'drawer_port';
  static const String _keyDrawerCommand = 'drawer_command';
  static const String _keyDrawerUsePrinter = 'drawer_use_printer';

  // Keys for Display
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyAutoOpenDisplay = 'auto_open_customer_display';
  static const String _keyPrinterBarcodeManualName =
      'printer_barcode_manual_name';

  // --- Generic Helpers ---

  Future<String?> getString(String key, {String? defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  // --- Getters ---

  Future<String?> getPrinterManualName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterBarcodeManualName);
  }

  Future<String?> getCashPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterCashName);
  }

  Future<String?> getCashBillPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterCashBillName);
  }

  Future<String?> getTaxPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterTaxName);
  }

  Future<String?> getDeliveryPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterDeliveryName);
  }

  Future<String?> getBarcodePrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterBarcodeName);
  }

  Future<String> getCashPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPaperSizeCash) ?? '80mm';
  }

  Future<String> getCashBillPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPaperSizeCashBill) ?? 'A4';
  }

  Future<String> getDeliveryPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPaperSizeDelivery) ?? 'A5';
  }

  Future<String> getBarcodePaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPaperSizeBarcode) ?? '40mmx30mm';
  }

  // Drawer
  Future<bool> getDrawerAutoOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDrawerAutoOpen) ?? false;
  }

  Future<String> getDrawerPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDrawerPort) ?? 'COM1';
  }

  Future<String> getDrawerCommand() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDrawerCommand) ?? '27,112,0,25,250';
  }

  Future<bool> getDrawerUsePrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDrawerUsePrinter) ?? true;
  }

  // Display
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<bool> getAutoOpenDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoOpenDisplay) ?? false;
  }

  // Auto Print
  Future<bool> getAutoPrintReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_print_receipt') ?? false;
  }

  Future<bool> getAutoPrintDeliveryNote() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_print_delivery_note') ?? false;
  }

  // --- Setters ---

  Future<void> setAutoPrintReceipt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_print_receipt', value);
  }

  Future<void> setAutoPrintDeliveryNote(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_print_delivery_note', value);
  }

  Future<void> setCashPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_keyPrinterCashName);
    } else {
      await prefs.setString(_keyPrinterCashName, name);
    }
  }

  Future<void> setCashBillPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_keyPrinterCashBillName);
    } else {
      await prefs.setString(_keyPrinterCashBillName, name);
    }
  }

  Future<void> setTaxPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_keyPrinterTaxName);
    } else {
      await prefs.setString(_keyPrinterTaxName, name);
    }
  }

  Future<void> setDeliveryPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_keyPrinterDeliveryName);
    } else {
      await prefs.setString(_keyPrinterDeliveryName, name);
    }
  }

  Future<void> setBarcodePrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_keyPrinterBarcodeName);
    } else {
      await prefs.setString(_keyPrinterBarcodeName, name);
    }
  }

  Future<void> setCashPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSizeCash, size);
  }

  Future<void> setCashBillPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSizeCashBill, size);
  }

  Future<void> setDeliveryPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSizeDelivery, size);
  }

  Future<void> setBarcodePaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSizeBarcode, size);
  }

  // Drawer
  Future<void> setDrawerAutoOpen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDrawerAutoOpen, value);
  }

  Future<void> setDrawerPort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDrawerPort, port);
  }

  Future<void> setDrawerCommand(String command) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDrawerCommand, command);
  }

  Future<void> setDrawerUsePrinter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDrawerUsePrinter, value);
  }

  // Display
  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  Future<void> setAutoOpenDisplay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoOpenDisplay, value);
  }
}
