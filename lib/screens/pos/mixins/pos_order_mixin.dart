part of '../pos_state_manager.dart';

extension PosOrderExtension on PosStateManager {
  Future<bool> shouldAutoPrint() async {
    final localSettings = LocalSettingsService();
    final pm = lastPaymentMethod.toUpperCase();
    if (pm.contains('CASH') || pm.contains('TRANSFER') || pm.contains('QR')) {
      return await localSettings.getBool('auto_print_receipt', defaultValue: false);
    }
    return await localSettings.getBool('auto_print_delivery_note', defaultValue: false);
  }

  void _updateDisplay() {
    if (cart.isEmpty && _currentCustomer == null) {
      _hardwareService.showIdle();
    } else {
      _hardwareService.updateCart(grandTotal: grandTotal, items: cart);
    }
  }

  void updateCustomerDisplay({double received = 0.0, double change = 0.0}) {
    _hardwareService.updateCart(
        grandTotal: grandTotal, items: cart, received: received, change: change);
  }

  Future<void> showPaymentQr(double amount) async {
    final globalSettings = SettingsService();
    final mode = globalSettings.getString('payment_qr_mode') ?? 'dynamic';
    String qrData = '';
    if (mode == 'dynamic') {
      final promptPayId = globalSettings.promptPayId;
      if (promptPayId.isNotEmpty) {
        qrData = PromptPayHelper.generatePayload(promptPayId, amount: amount);
      }
    }
    await _hardwareService.showQrCode(
        qrData: qrData, amount: amount, total: grandTotal, items: cart);
  }

  void resetDisplay() => _updateDisplay();

  Future<int> saveOrder({
    required List<PaymentRecord> payments,
    DeliveryType deliveryType = DeliveryType.none,
    String? note,
  }) async {
    try {
      final orderId = await _orderService.processOrder(
        cart: cart,
        currentCustomer: _currentCustomer,
        payments: payments,
        total: total,
        discountAmount: discountAmount,
        grandTotal: grandTotal,
        deliveryType: deliveryType,
        note: note,
        pointsUsed: _pointsToRedeem,
        activePromotions: _activePromotions,
        currentTier: currentTier,
      );

      final currentItems = List<OrderItem>.from(cart);
      final currentCust = _currentCustomer;
      final currentTotal = grandTotal;
      final received = payments.fold(0.0, (sum, p) => sum + p.amount);
      final currentChange = (received - grandTotal).clamp(0.0, double.infinity);
      final paymentMethodStr = payments.map((p) => p.method).join(',');

      if (_appliedCouponCode != null) {
        try {
          await RewardRepository().useCoupon(_appliedCouponCode!, orderId);
        } catch (e) {
          debugPrint('⚠️ Error marking coupon as used: $e');
        }
      }

      _lastOrder = LastOrderInfo(
        orderId: orderId,
        items: currentItems,
        customer: currentCust,
        grandTotal: currentTotal,
        received: received,
        change: currentChange,
        paymentMethod: paymentMethodStr,
        discountAmount: discountAmount,
        payments: payments,
        orderTime: DateTime.now(),
      );

      if (deliveryType == DeliveryType.delivery ||
          deliveryType == DeliveryType.pickup) {
        _processDeliveryJobInBackground(
          orderId, deliveryType, currentCust, currentItems,
          grandTotal, received, discountAmount, vatAmount, payments,
          manualNote: note,
        );
      }

      _hardwareService.openDrawer().catchError((e) => debugPrint('Drawer Error: $e'));
      _hardwareService.setSuppressDisplay(true);

      await clearCart(returnStock: false);
      _couponDiscountAmount = 0.0;
      _appliedCouponCode = null;
      _pointsToRedeem = 0;

      await _hardwareService.showSuccess(
        received: received,
        change: currentChange,
        total: grandTotal,
        items: currentItems,
      );
      return orderId;
    } catch (e) {
      debugPrint('Save Order Delegated Error: $e');
      rethrow;
    }
  }
}
