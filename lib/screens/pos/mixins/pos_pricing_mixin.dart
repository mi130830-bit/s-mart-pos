part of '../pos_state_manager.dart';

extension PosPricingExtension on PosStateNotifier {
  void setVatType(VatType type) {
    _vatType = type;
    _invalidateCalcCache();
    _notify();
  }

  void _invalidateCalcCache() => _calcCache = null;

  PriceCalculationResult get _calcResult {
    return _calcCache ??= _priceCalcService.calculateTotals(
      cart: cart,
      billDiscountVal: _billDiscount,
      isPercentDiscount: _isPercentDiscount,
      promoDiscountVal: _promoDiscount.toDouble(),
      extraDiscountVal: _extraBillDiscount,
      pointDiscountAmount: pointDiscountAmount,
      vatType: _vatType,
      customer: _currentCustomer,
      tier: currentTier,
      roundingMode: _roundingMode,
      vatRate: _vatRate,
    );
  }

  double get vatAmount => _calcResult.vatAmount.toDouble();

  double get grandTotal {
    final base = _calcResult.grandTotal.toDouble();
    final afterCoupon = base - _couponDiscountAmount;
    return afterCoupon < 0 ? 0 : afterCoupon;
  }

  double get discountAmount =>
      _calcResult.billDiscountAmount.toDouble() +
      _calcResult.extraDiscountAmount.toDouble() +
      _promoDiscount.toDouble() +
      pointDiscountAmount +
      _couponDiscountAmount;

  double get promoDiscount => _promoDiscount.toDouble();

  void applyPointDiscount(int points) {
    _pointsToRedeem = points;
    _invalidateCalcCache();
    _notify();
  }

  void clearPointDiscount() {
    _pointsToRedeem = 0;
    _invalidateCalcCache();
    _notify();
  }

  void applyCouponDiscount(double amount, String? couponCode) {
    _couponDiscountAmount = amount;
    _appliedCouponCode = couponCode;
    _invalidateCalcCache();
    _notify();
  }

  void clearCouponDiscount() {
    _couponDiscountAmount = 0.0;
    _appliedCouponCode = null;
    _invalidateCalcCache();
    _notify();
  }

  void _calculatePromotions() {
    final result =
        _priceCalcService.calculatePromotions(cart, _activePromotions);
    _promoDiscount = result.discountAmount;
    _appliedPromotion = result.appliedPromotion;
    if (result.freeItems.isNotEmpty) {
      unawaited(_applyFreeItems(result.freeItems));
    }
  }

  Future<void> _applyFreeItems(List<FreeItemRequest> requests) async {
    for (final req in requests) {
      final alreadyFree = cart.any((item) =>
          item.productId == req.productId && item.comment.contains('🎁'));
      if (alreadyFree) continue;
      try {
        final product = await _productRepo.getProductById(req.productId);
        if (product == null) continue;
        await _cartService.addProduct(
          product: product,
          quantity: Decimal.parse(req.quantity.toString()),
          overridePrice: Decimal.zero,
          customer: _currentCustomer,
          tier: currentTier,
        );
        final newIndex = cart.length - 1;
        if (newIndex >= 0) {
          _cartService.updateItemComment(newIndex,
              "🎁 แถมฟรี (${_appliedPromotion?.name ?? 'โปรโมชั่น'})");
        }
      } catch (e) {
        debugPrint('⚠️ Free item error: $e');
      }
    }
  }

  void selectCustomer(Customer? customer) {
    _currentCustomer = customer;
    _invalidateCalcCache();
    _cartService.recalculateAllPrices(customer, currentTier);
    _saveCartToPrefs();
    _notify();
  }

  void clearCustomer() {
    _currentCustomer = null;
    _invalidateCalcCache();
    _cartService.recalculateAllPrices(null, null);
    _saveCartToPrefs();
    _notify();
  }

  void setBillDiscount(double value, {bool isPercent = false}) {
    _billDiscount = value;
    _isPercentDiscount = isPercent;
    _invalidateCalcCache();
    _saveCartToPrefs();
    _notify();
  }
}
