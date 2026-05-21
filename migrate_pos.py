import os
import re

def migrate_pos_state():
    pos_file = 'lib/screens/pos/pos_state_manager.dart'
    with open(pos_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add riverpod import
    if "import 'package:flutter_riverpod/flutter_riverpod.dart';" not in content:
        content = content.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';")

    pos_state_class = '''
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
    this.shopName = 'ร้านส.บริการ ท่าข้าม',
    this.allowNegativeStock = true,
    this.roundingMode = 'none',
    this.vatRate = 7.0,
    this.allowPriceEdit = false,
    this.authUser,
    this.vatType = VatType.none,
  });

  PosState copyWith({
    Customer? currentCustomer,
    bool clearCurrentCustomer = false,
    List<HeldBill>? heldBills,
    double? billDiscount,
    bool? isPercentDiscount,
    double? extraBillDiscount,
    LastOrderInfo? lastOrder,
    bool clearLastOrder = false,
    PriceCalculationResult? calcCache,
    bool clearCalcCache = false,
    List<MemberTier>? tiers,
    List<Promotion>? activePromotions,
    Decimal? promoDiscount,
    Promotion? appliedPromotion,
    bool clearAppliedPromotion = false,
    int? pointsToRedeem,
    double? couponDiscountAmount,
    String? appliedCouponCode,
    bool clearAppliedCouponCode = false,
    int? currentBranchId,
    String? shopName,
    bool? allowNegativeStock,
    String? roundingMode,
    double? vatRate,
    bool? allowPriceEdit,
    User? authUser,
    bool clearAuthUser = false,
    VatType? vatType,
  }) {
    return PosState(
      currentCustomer: clearCurrentCustomer ? null : (currentCustomer ?? this.currentCustomer),
      heldBills: heldBills ?? this.heldBills,
      billDiscount: billDiscount ?? this.billDiscount,
      isPercentDiscount: isPercentDiscount ?? this.isPercentDiscount,
      extraBillDiscount: extraBillDiscount ?? this.extraBillDiscount,
      lastOrder: clearLastOrder ? null : (lastOrder ?? this.lastOrder),
      calcCache: clearCalcCache ? null : (calcCache ?? this.calcCache),
      tiers: tiers ?? this.tiers,
      activePromotions: activePromotions ?? this.activePromotions,
      promoDiscount: promoDiscount ?? this.promoDiscount,
      appliedPromotion: clearAppliedPromotion ? null : (appliedPromotion ?? this.appliedPromotion),
      pointsToRedeem: pointsToRedeem ?? this.pointsToRedeem,
      couponDiscountAmount: couponDiscountAmount ?? this.couponDiscountAmount,
      appliedCouponCode: clearAppliedCouponCode ? null : (appliedCouponCode ?? this.appliedCouponCode),
      currentBranchId: currentBranchId ?? this.currentBranchId,
      shopName: shopName ?? this.shopName,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      roundingMode: roundingMode ?? this.roundingMode,
      vatRate: vatRate ?? this.vatRate,
      allowPriceEdit: allowPriceEdit ?? this.allowPriceEdit,
      authUser: clearAuthUser ? null : (authUser ?? this.authUser),
      vatType: vatType ?? this.vatType,
    );
  }
}

final posProvider = NotifierProvider.autoDispose<PosStateNotifier, PosState>(PosStateNotifier.new);

class PosStateNotifier extends AutoDisposeNotifier<PosState> {
  // Internal helper for extension methods to trigger Riverpod updates easily
  // while we migrate piece by piece.
  void _notify() {
    state = state.copyWith(
      currentCustomer: _currentCustomer,
      heldBills: _heldBills,
      billDiscount: _billDiscount,
      isPercentDiscount: _isPercentDiscount,
      extraBillDiscount: _extraBillDiscount,
      lastOrder: _lastOrder,
      calcCache: _calcCache,
      tiers: _tiers,
      activePromotions: _activePromotions,
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
      clearCurrentCustomer: _currentCustomer == null,
      clearLastOrder: _lastOrder == null,
      clearCalcCache: _calcCache == null,
      clearAppliedPromotion: _appliedPromotion == null,
      clearAppliedCouponCode: _appliedCouponCode == null,
      clearAuthUser: _authUser == null,
    );
  }
  
  @override
  PosState build() {
    _cartService = ref.read(cartProvider.notifier);
    
    // Listen to cart changes to replicate addListener
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
  }
'''
    
    content = re.sub(r'class PosStateManager extends ChangeNotifier \{', pos_state_class, content)

    # Remove PosStateManager() constructor logic entirely
    # The constructor is usually PosStateManager() { ... }
    # Let's replace it with an empty constructor or remove it since build() handles it
    content = re.sub(r'  PosStateManager\(\) \{.*?_init\(\);\n  \}', '', content, flags=re.DOTALL)

    with open(pos_file, 'w', encoding='utf-8') as f:
        f.write(content)

    # Replace PosStateManager with PosStateNotifier in all mixins
    mixins = [
        'lib/screens/pos/mixins/pos_pricing_mixin.dart',
        'lib/screens/pos/mixins/pos_cart_mixin.dart',
        'lib/screens/pos/mixins/pos_order_mixin.dart',
        'lib/screens/pos/mixins/pos_delivery_mixin.dart',
        'lib/screens/pos/mixins/pos_barcode_handler_mixin.dart'
    ]
    for mixin_file in mixins:
        if os.path.exists(mixin_file):
            with open(mixin_file, 'r', encoding='utf-8') as f:
                mixin_content = f.read()
            mixin_content = mixin_content.replace('on PosStateManager', 'on PosStateNotifier')
            with open(mixin_file, 'w', encoding='utf-8') as f:
                f.write(mixin_content)

if __name__ == '__main__':
    migrate_pos_state()
