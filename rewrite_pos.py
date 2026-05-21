import os

def rewrite():
    with open('lib/screens/pos/pos_state_manager.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Imports
    content = content.replace(
        "import 'package:flutter/foundation.dart';", 
        "import 'package:flutter/foundation.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';"
    )

    state_class = """
class PosState {
  final Customer? currentCustomer;
  final List<HeldBill> heldBills;
  final double billDiscount;
  final bool isPercentDiscount;
  final double extraBillDiscount;
  final LastOrderInfo? lastOrder;
  final PriceCalculationResult? calcCache;
  final List<MemberTier> tiers;
  final List<Promotion> activePromotions;
  final Decimal promoDiscount;
  final Promotion? appliedPromotion;
  final int pointsToRedeem;
  final double couponDiscountAmount;
  final String? appliedCouponCode;
  final int currentBranchId;
  final String shopName;
  final bool allowNegativeStock;
  final String roundingMode;
  final double vatRate;
  final bool allowPriceEdit;
  final User? authUser;
  final VatType vatType;

  PosState({
    this.currentCustomer,
    this.heldBills = const [],
    this.billDiscount = 0.0,
    this.isPercentDiscount = false,
    this.extraBillDiscount = 0.0,
    this.lastOrder,
    this.calcCache,
    this.tiers = const [],
    this.activePromotions = const [],
    required this.promoDiscount,
    this.appliedPromotion,
    this.pointsToRedeem = 0,
    this.couponDiscountAmount = 0.0,
    this.appliedCouponCode,
    this.currentBranchId = 1,
    this.shopName = '',
    this.allowNegativeStock = true,
    this.roundingMode = 'none',
    this.vatRate = 7.0,
    this.allowPriceEdit = false,
    this.authUser,
    this.vatType = VatType.none,
  });
}

final posProvider = NotifierProvider.autoDispose<PosStateNotifier, PosState>(PosStateNotifier.new);

class PosStateNotifier extends AutoDisposeNotifier<PosState> {
  // Internal helper for extension methods
  void _notify() {
    state = PosState(
      currentCustomer: _currentCustomer,
      heldBills: List.unmodifiable(_heldBills),
      billDiscount: _billDiscount,
      isPercentDiscount: _isPercentDiscount,
      extraBillDiscount: _extraBillDiscount,
      lastOrder: _lastOrder,
      calcCache: _calcCache,
      tiers: List.unmodifiable(_tiers),
      activePromotions: List.unmodifiable(_activePromotions),
      promoDiscount: _promoDiscount,
      appliedPromotion: _appliedPromotion,
      pointsToRedeem: _pointsToRedeem,
      couponDiscountAmount: _couponDiscountAmount,
      appliedCouponCode: _appliedCouponCode,
      currentBranchId: _currentBranchId,
      shopName: _shopName,
      allowNegativeStock: _allowNegativeStock,
      roundingMode: _roundingMode,
      vatRate: _vatRate,
      allowPriceEdit: _allowPriceEdit,
      authUser: _authUser,
      vatType: _vatType,
    );
  }
"""

    content = content.replace("class PosStateManager extends ChangeNotifier {", state_class)
    content = content.replace("  void _notify() => notifyListeners();", "")

    # Constructor replacement
    old_constructor = """  PosStateManager() {
    _cartService = CartService(MySQLService(), _priceCalcService);
    _deliveryService =
        DeliveryIntegrationService(MySQLService(), _firebaseService);

    _cartService.addListener(() {
      _invalidateCalcCache();
      _calculatePromotions();
      _updateDisplay();
      _saveCartToPrefs();
      notifyListeners();
    });

    SettingsService().addListener(() {
      refreshGeneralSettings();
    });

    _init();
  }"""
    
    new_build = """  @override
  PosState build() {
    _deliveryService = DeliveryIntegrationService(MySQLService(), _firebaseService);

    ref.listen(cartProvider, (prev, next) {
      _invalidateCalcCache();
      _calculatePromotions();
      _updateDisplay();
      _saveCartToPrefs();
      _notify();
    });

    SettingsService().addListener(() {
      refreshGeneralSettings();
    });

    _init();

    return PosState(promoDiscount: Decimal.zero);
  }"""
    
    content = content.replace(old_constructor, new_build)

    # Cart accessors
    content = content.replace("late CartService _cartService;", "CartNotifier get _cartService => ref.read(cartProvider.notifier);")
    content = content.replace("List<OrderItem> get cart => _cartService.cart;", "List<OrderItem> get cart => ref.read(cartProvider).items;")

    # Replace notifyListeners() with _notify()
    content = content.replace("notifyListeners();", "_notify();")

    with open('lib/screens/pos/pos_state_manager.dart', 'w', encoding='utf-8') as f:
        f.write(content)

    # Replace in Mixins
    mixins = [
        'lib/screens/pos/mixins/pos_pricing_mixin.dart',
        'lib/screens/pos/mixins/pos_cart_mixin.dart',
        'lib/screens/pos/mixins/pos_order_mixin.dart',
        'lib/screens/pos/mixins/pos_delivery_mixin.dart',
        'lib/screens/pos/mixins/pos_barcode_handler_mixin.dart'
    ]
    for mixin in mixins:
        if os.path.exists(mixin):
            with open(mixin, 'r', encoding='utf-8') as f:
                mx_content = f.read()
            mx_content = mx_content.replace('PosStateManager', 'PosStateNotifier')
            with open(mixin, 'w', encoding='utf-8') as f:
                f.write(mx_content)

rewrite()
