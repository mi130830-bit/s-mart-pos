import 'package:flutter/foundation.dart';
import '../customer_display_service.dart';
import '../printing/receipt_service.dart';
import '../../models/order_item.dart';

class HardwareService {
  // Singleton
  static final HardwareService _instance = HardwareService._internal();
  factory HardwareService() => _instance;
  HardwareService._internal();

  final CustomerDisplayService _displayService = CustomerDisplayService();
  final ReceiptService _receiptService = ReceiptService();

  // --- Customer Display ---
  bool _suppressDisplayUpdate = false;

  void setSuppressDisplay(bool value) {
    _suppressDisplayUpdate = value;
  }

  Future<void> openDisplay() async {
    await _displayService.openDisplay();
  }

  void closeDisplay() {
    _displayService.closeDisplay();
  }

  void updateCart({
    required double grandTotal,
    required List<OrderItem> items,
    double received = 0.0,
    double change = 0.0,
  }) {
    if (_suppressDisplayUpdate) return;
    if (_displayService.isOpen) {
      _displayService.updateCart(
        total: grandTotal,
        items: items,
        received: received,
        change: change,
      );
    }
  }

  void showIdle() {
    if (_suppressDisplayUpdate) return;
    if (_displayService.isOpen) {
      _displayService.showIdle();
    }
  }

  Future<void> showSuccess({
    required double received,
    required double change,
    required double total,
    required List<OrderItem> items,
  }) async {
    // We allow success screen even if suppressed (usually we suppress TO show success)
    if (_displayService.isOpen) {
      await _displayService.showSuccess(
        received: received,
        change: change,
        total: total,
        items: items,
      );
    }
  }

  Future<void> showQrCode({
    required String qrData,
    required double amount,
    required double total,
    required List<OrderItem> items,
  }) async {
    if (_displayService.isOpen) {
      await _displayService.showQrCode(
        qrData: qrData,
        amount: amount,
        total: total,
        items: items,
        received: amount,
        change: 0.0,
      );
    }
  }

  // --- Cash Drawer ---
  Future<void> openDrawer() async {
    try {
      await _receiptService.openDrawer();
    } catch (e) {
      debugPrint('HardwareService: Failed to open drawer: $e');
    }
  }
}
