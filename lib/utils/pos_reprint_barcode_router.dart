import 'package:flutter/foundation.dart';

/// A global singleton that allows payment_modal.dart to pass a "pending barcode"
/// (scanned during the reprint dialog) back to the POS checkout screen
/// without needing a BuildContext bridge.
///
/// Usage:
///   // In payment_modal (sender):
///   PosReprintBarcodeRouter.broadcast(scannedBarcode);
///
///   // In pos_checkout_screen (receiver):
///   void initState() {
///     PosReprintBarcodeRouter.instance.addListener(_onPendingBarcode);
///   }
///   void _onPendingBarcode() {
///     final code = PosReprintBarcodeRouter.instance.value;
///     if (code != null) {
///       PosReprintBarcodeRouter.consume(); // clear
///       _handleBarcodeSubmit(code, posState);
///     }
///   }
class PosReprintBarcodeRouter {
  PosReprintBarcodeRouter._();

  static final ValueNotifier<String?> instance = ValueNotifier<String?>(null);

  /// Call this from payment_modal.dart after dialog closes with a scanned barcode.
  static void broadcast(String barcode) {
    debugPrint('📡 [PosReprintBarcodeRouter] broadcast: $barcode');
    instance.value = barcode;
  }

  /// Call this from pos_checkout_screen.dart after consuming the barcode.
  static void consume() {
    instance.value = null;
  }
}
