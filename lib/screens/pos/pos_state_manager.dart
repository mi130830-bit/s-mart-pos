import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import '../../models/user.dart';
import 'package:decimal/decimal.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/order_item.dart';
import '../../models/payment_record.dart';
import '../../models/member_tier.dart';
import '../../models/promotion.dart';
import '../../models/last_order_info.dart';
import '../../services/mysql_service.dart';
import '../../repositories/promotion_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../services/firebase_service.dart';
import '../../services/printing/receipt_service.dart';
import '../../repositories/customer_repository.dart';
import '../../utils/promptpay_helper.dart';
import '../../services/sales/order_processing_service.dart';
import '../../models/delivery_type.dart';
import '../../services/sales/held_bill_manager.dart';
import '../../services/settings_service.dart';
import '../../services/local_settings_service.dart';
import '../../services/sales/price_calculation_service.dart';
import '../../services/sales/cart_service.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../../services/system/hardware_service.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/reward_repository.dart';
import '../../utils/barcode_utils.dart';
import '../../services/logger_service.dart';

export '../../services/sales/price_calculation_service.dart' show VatType;

part 'mixins/pos_pricing_mixin.dart';
part 'mixins/pos_cart_mixin.dart';
part 'mixins/pos_order_mixin.dart';
part 'mixins/pos_delivery_mixin.dart';

enum ScanStatus { success, notFound, multipleMatches, error, requiresWeight }

class ScanResult {
  final ScanStatus status;
  final Product? product;
  final List<Product>? matches;
  final String? message;

  ScanResult({required this.status, this.product, this.matches, this.message});
}

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

  final FirebaseService _firebaseService = FirebaseService();
  final PriceCalculationService _priceCalcService = PriceCalculationService();
  final HardwareService _hardwareService = HardwareService();
  late DeliveryIntegrationService _deliveryService;


  Customer? _currentCustomer;
  CartNotifier get _cartService => ref.read(cartProvider.notifier);
  List<OrderItem> get cart => ref.read(cartProvider).items;

  final HeldBillManager _heldBillManager = HeldBillManager();
  final SalesRepository _salesRepo = SalesRepository();
  final OrderProcessingService _orderService = OrderProcessingService();

  final List<HeldBill> _heldBills = [];

  double _billDiscount = 0.0;
  bool _isPercentDiscount = false;

  // ✅ Extra Manual Discount
  double _extraBillDiscount = 0.0;
  double get extraBillDiscount => _extraBillDiscount;

  // Fix 2 Phase 7.1: รวม 8 last-order fields เป็น model เดียว
  LastOrderInfo? _lastOrder;

  // Fix 1 Phase 7.1: Cache ผลคำนวณ — invalidate เมื่อ cart/discount/customer เปลี่ยน
  PriceCalculationResult? _calcCache;

  // ระบบ CRM - ระดับสมาชิก (Tiers)
  List<MemberTier> _tiers = [];
  final CustomerRepository _custRepo = CustomerRepository();
  final ProductRepository _productRepo = ProductRepository();

  // โปรโมชั่น (Promotions)
  List<Promotion> _activePromotions = [];
  final PromotionRepository _promoRepo = PromotionRepository();

  Decimal _promoDiscount = Decimal.zero;
  Promotion? _appliedPromotion;
  Promotion? get appliedPromotion => _appliedPromotion;

  // ✅ Point Redemption State
  int _pointsToRedeem = 0;
  double get pointsToRedeem => _pointsToRedeem.toDouble();
  double get pointDiscountAmount {
    final rate = SettingsService().pointRedemptionRate;
    if (rate <= 0 || _pointsToRedeem <= 0) return 0.0;
    return _pointsToRedeem / rate;
  }

  // ✅ Coupon Discount State
  double _couponDiscountAmount = 0.0;
  String? _appliedCouponCode;
  double get couponDiscountAmount => _couponDiscountAmount;
  String? get appliedCouponCode => _appliedCouponCode;

  final int _currentBranchId = 1;
  int get currentBranchId => _currentBranchId;
  String _shopName = 'ร้านส.บริการ ท่าข้าม';
  String get shopName => _shopName;
  bool _allowNegativeStock = true;
  String _roundingMode = 'none';
  double _vatRate = 7.0;
  bool _allowPriceEdit = false;
  bool get allowPriceEdit => _allowPriceEdit;

  @override
  PosState build() {
    _deliveryService =
        DeliveryIntegrationService(MySQLService(), _firebaseService);

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

  Future<void> _init() async {
    if (!await MySQLService().hasConfig()) {
      LoggerService.warning('POS_State', 'No Database Config found. Skipping DB Init.');
      return;
    }

    try {
      await _custRepo.initMemberTierTable();
      _tiers = await _custRepo.getAllTiers();
    } catch (e) {
      LoggerService.error('POS_State', 'Init Error', e);
    }

    await _promoRepo.initTable();
    _activePromotions = await _promoRepo.getAllPromotions(activeOnly: true);

    await _loadCartFromPrefs();
    await _loadHeldBillsFromDB();
    refreshGeneralSettings();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_open_customer_display') ?? false) {
      _hardwareService.openDisplay();
    }
    _notify();
  }

  Future<void> refreshGeneralSettings() async {
    final settings = SettingsService();
    final rate = settings.memberDiscountRate;
    _priceCalcService.updateSettings(memberDiscountRate: rate);

    _shopName = settings.shopName;
    _allowNegativeStock = settings.allowNegativeStock;
    _cartService.setAllowNegativeStock(_allowNegativeStock);

    _roundingMode = settings.roundingMode;
    _vatRate = settings.vatRate;
    _allowPriceEdit =
        settings.getBool('allow_pos_price_edit', defaultValue: false);

    unawaited(_promoRepo.getAllPromotions(activeOnly: true).then((promos) {
      _activePromotions = promos;
      _calculatePromotions();
      _invalidateCalcCache();
      _notify();
    }));

    _notify();
  }

  // --- Auth User ---
  User? _authUser;

  Future<void> updateUser(User? newUser) async {
    if (_authUser?.id != newUser?.id) {
      if (_authUser != null) {
        await _saveCartToPrefs();
      }
      _clearStateMemory();
      _authUser = newUser;
      await _loadCartFromPrefs();
      _notify();
    }
  }

  User? get currentUser => _authUser;

  void _clearStateMemory() {
    _currentCustomer = null;
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _extraBillDiscount = 0.0;
    _promoDiscount = Decimal.zero;
    _cartService.clearCart();
  }

  void setExtraBillDiscount(double val) {
    _extraBillDiscount = val;
    _invalidateCalcCache();
    _notify();
  }

  // --- Active Cart Persistence ---
  Future<void> _saveCartToPrefs() async {
    await _cartService.saveCartToPrefs(
        customerId: _currentCustomer?.id,
        discountVal: _billDiscount,
        isPercent: _isPercentDiscount,
        userId: _authUser?.id.toString());
  }

  Future<void> _loadCartFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _authUser?.id != null ? '${_authUser!.id}_' : '';

    final custId = prefs.getInt('${prefix}cart_customer_id');

    if (custId != null) {
      try {
        _currentCustomer = await _custRepo.getCustomerById(custId);
      } catch (e) {
        LoggerService.warning('POS_State', '_loadCartFromPrefs customer error: $e');
        _currentCustomer = null;
      }
    } else {
      _currentCustomer = null;
    }

    _billDiscount = prefs.getDouble('${prefix}cart_discount') ?? 0.0;
    _isPercentDiscount =
        prefs.getBool('${prefix}cart_is_percent_discount') ?? false;

    await _cartService.loadCartFromPrefs((loadedItems) {},
        userId: _authUser?.id.toString());
  }

  // --- Held Bills ---
  Future<void> _loadHeldBillsFromDB() async {
    final bills = await _heldBillManager.loadHeldBills();
    _heldBills.clear();
    _heldBills.addAll(bills);
    _notify();
  }

  Future<void> holdCurrentBill({String note = ''}) async {
    if (cart.isEmpty) return;
    try {
      await _heldBillManager.holdBill(
          cart: cart, currentCustomer: _currentCustomer, note: note);
      await clearCart(returnStock: false);
      await _loadHeldBillsFromDB();
    } catch (e) {
      LoggerService.error('POS_State', 'Error holding bill', e);
      rethrow;
    }
  }

  Future<List<String>> checkHeldBillStock(int index) async {
    if (index < 0 || index >= _heldBills.length) return [];
    final heldBill = _heldBills[index];
    final warnings = <String>[];

    try {
      final productIds = heldBill.items.map((item) => item.productId).toList();
      final products = await _productRepo.getProductsByIds(productIds);
      final productMap = {for (var p in products) p.id: p};

      for (var item in heldBill.items) {
        final p = productMap[item.productId];
        if (p != null) {
          if (p.stockQuantity < item.quantity.toDouble()) {
            warnings.add(
                '- ${p.name}\n  (ต้องการ: ${item.quantity.toStringAsFixed(0)}, มี: ${p.stockQuantity.toStringAsFixed(0)})');
          }
        } else {
          warnings.add('- สินค้ารหัส ${item.productId} ไม่พบในระบบ');
        }
      }
    } catch (e) {
      LoggerService.error('POS_State', 'Error checking stock for held bill', e);
    }

    return warnings;
  }

  Future<void> recallHeldBill(int index) async {
    if (index < 0 || index >= _heldBills.length) return;
    final heldBill = _heldBills[index];

    if (heldBill.id != null) {
      await _heldBillManager.removeBillRecord(heldBill.id!);
    }

    _currentCustomer = heldBill.customer;
    _cartService.setCart(heldBill.items);
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _extraBillDiscount = 0.0;

    _heldBills.removeAt(index);
    _notify();
  }

  Future<void> deleteHeldBill(int index) async {
    final heldBill = _heldBills[index];
    await _heldBillManager.deleteHeldBill(heldBill);
    await _loadHeldBillsFromDB();
  }

  Future<void> clearAllHeldBills() async {
    await _heldBillManager.clearAll();
    await _loadHeldBillsFromDB();
  }

  Future<void> clearOldHeldBills(int days) async {
    await _heldBillManager.clearOldHeldBills(days);
    await _loadHeldBillsFromDB();
  }

  // --- Getters ---
  Customer? get currentCustomer => _currentCustomer;
  List<HeldBill> get heldBills => List.unmodifiable(_heldBills);
  double get billDiscount => _billDiscount;
  bool get isPercentDiscount => _isPercentDiscount;

  LastOrderInfo? get lastOrder => _lastOrder;
  List<OrderItem> get lastSoldItems =>
      _lastOrder != null ? List.unmodifiable(_lastOrder!.items) : [];
  Customer? get lastSoldCustomer => _lastOrder?.customer;
  int get lastOrderId => _lastOrder?.orderId ?? 0;
  double get lastGrandTotal => _lastOrder?.grandTotal ?? 0.0;
  double get lastReceived => _lastOrder?.received ?? 0.0;
  double get lastChange => _lastOrder?.change ?? 0.0;
  String get lastPaymentMethod => _lastOrder?.paymentMethod ?? '';
  double get lastDiscountAmount => _lastOrder?.discountAmount ?? 0.0;
  List<PaymentRecord> get lastPayments =>
      _lastOrder != null ? List.unmodifiable(_lastOrder!.payments) : [];
  DateTime? get lastOrderTime => _lastOrder?.orderTime;

  MemberTier? get currentTier {
    if (_currentCustomer == null || _currentCustomer!.tierId == null) {
      return null;
    }
    return _tiers.firstWhere((t) => t.id == _currentCustomer!.tierId,
        orElse: () => MemberTier(id: 0, name: 'Standard'));
  }

  double get subtotalBeforeDiscount =>
      cart.fold(Decimal.zero, (sum, item) => sum + item.total).toDouble();
  double get total => subtotalBeforeDiscount; // backward compat

  VatType _vatType = VatType.none;
  VatType get vatType => _vatType;
}
