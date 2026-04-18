import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart'; // ✅ Added for PageFormat
import '../../models/user.dart';
import 'package:decimal/decimal.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/order_item.dart';
import '../../models/payment_record.dart';
import '../../models/member_tier.dart';
import '../../models/promotion.dart';
import '../../models/last_order_info.dart'; // Fix 2 Phase 7.1
import '../../services/mysql_service.dart';
import '../../repositories/promotion_repository.dart';
import '../../repositories/sales_repository.dart'; // Fix 6 Phase 7.1
import '../../services/firebase_service.dart';
import '../../services/printing/receipt_service.dart'; // ✅ Restored for PDF Gen
import '../../repositories/customer_repository.dart';
import '../../utils/promptpay_helper.dart';
import '../../services/sales/order_processing_service.dart';
import '../../models/delivery_type.dart';
import '../../services/sales/held_bill_manager.dart';

import '../../services/settings_service.dart';
import '../../services/local_settings_service.dart';

// บริการใหม่ (New Services)

import '../../services/sales/price_calculation_service.dart';
import '../../services/sales/cart_service.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../../services/system/hardware_service.dart'; // ✅ Added

import '../../repositories/product_repository.dart';
import '../../repositories/reward_repository.dart';
// import '../../utils/thai_helper.dart';
import '../../utils/barcode_utils.dart'; // Added

export '../../services/sales/price_calculation_service.dart' show VatType;

enum ScanStatus { success, notFound, multipleMatches, error, requiresWeight }

class ScanResult {
  final ScanStatus status;
  final Product? product;
  final List<Product>? matches;
  final String? message;

  ScanResult({required this.status, this.product, this.matches, this.message});
}

class PosStateManager extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  final PriceCalculationService _priceCalcService = PriceCalculationService();
  final HardwareService _hardwareService = HardwareService(); // ✅ Use Service
  late CartService _cartService;
  late DeliveryIntegrationService _deliveryService;

  Customer? _currentCustomer;
  // เราเปิดเผยตะกร้าสินค้าจาก CartService (อาจจะห่อหุ้มหรือเรียกใช้ตรงๆ)
  List<OrderItem> get cart => _cartService.cart;

  final HeldBillManager _heldBillManager = HeldBillManager();
  // Fix 6 Phase 7.1: SalesRepository เพื่อดึง order data ผ่าน repo ไม่ใช้ raw SQL
  final SalesRepository _salesRepo = SalesRepository();

  final List<HeldBill> _heldBills = [];

  double _billDiscount = 0.0;
  bool _isPercentDiscount = false;

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

  // แคชผลลัพธ์การคำนวณ
  Decimal _promoDiscount = Decimal.zero;

  // ✅ Point Redemption State
  int _pointsToRedeem = 0;
  double get pointsToRedeem => _pointsToRedeem.toDouble();
  double get pointDiscountAmount {
    final rate = SettingsService().pointRedemptionRate;
    if (rate <= 0 || _pointsToRedeem <= 0) return 0.0;
    return _pointsToRedeem / rate;
  }

  // ✅ Coupon Discount State (Phase 2)
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
  bool _allowPriceEdit = false; // Added
  bool get allowPriceEdit =>
      _allowPriceEdit; // Check SettingsService default implied?

  PosStateManager() {
    _cartService = CartService(MySQLService(), _priceCalcService);
    _deliveryService =
        DeliveryIntegrationService(MySQLService(), _firebaseService);

    // Listen to CartService to propagate notifications
    _cartService.addListener(() {
      _invalidateCalcCache(); // Fix 1: invalidate เมื่อ cart เปลี่ยน
      _calculatePromotions();
      _updateDisplay();
      _saveCartToPrefs();
      notifyListeners();
    });

    // ✅ Listen to Global Settings changes
    SettingsService().addListener(() {
      refreshGeneralSettings();
    });

    _init();
  }

  Future<void> _init() async {
    // ✅ Check for DB Config before trying to connect
    if (!await MySQLService().hasConfig()) {
      debugPrint('⚠️ [PosState] No Database Config found. Skipping DB Init.');
      return;
    }

    try {
      await _custRepo.initMemberTierTable();
      _tiers = await _custRepo.getAllTiers();
    } catch (e) {
      debugPrint('❌ [PosState] Init Error: $e');
      // Continue safely?
    }

    await _promoRepo.initTable();
    _activePromotions = await _promoRepo.getAllPromotions(activeOnly: true);

    await _loadCartFromPrefs();
    await _loadHeldBillsFromDB();
    refreshGeneralSettings();
    // Auto-open Customer Display if needed/connected (Handled via Settings typically, or HardwareService)
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_open_customer_display') ?? false) {
      _hardwareService.openDisplay();
    }
    notifyListeners();
  }

  Future<void> refreshGeneralSettings() async {
    final settings = SettingsService();
    // Ensure settings are loaded or use getters that rely on cached values?
    // SettingsService loads on app start, but let's be safe if it needs init.
    // Ideally SettingsService is singleton and pre-loaded.

    // Global Settings
    final rate = settings.memberDiscountRate;
    _priceCalcService.updateSettings(memberDiscountRate: rate);

    _shopName = settings.shopName;
    _allowNegativeStock = settings.allowNegativeStock;
    _allowNegativeStock = settings.allowNegativeStock;
    _cartService.setAllowNegativeStock(_allowNegativeStock);

    // Rounding
    _roundingMode = settings.roundingMode;
    _allowPriceEdit =
        settings.getBool('allow_pos_price_edit', defaultValue: false);
    notifyListeners();
  }

  // auth user tracking
  User? _authUser;

  // Update from AuthProvider
  Future<void> updateUser(User? newUser) async {
    // If user changed
    if (_authUser?.id != newUser?.id) {
      // Save current state for old user if possible?
      // Actually _saveCartToPrefs uses _authUser, so if we haven't updated _authUser yet,
      // we are saving for the OLD user.
      if (_authUser != null) {
        await _saveCartToPrefs();
      }

      // Clear current memory state
      _clearStateMemory();

      // Switch user
      _authUser = newUser;

      // Load state for new user
      await _loadCartFromPrefs();
      notifyListeners();
    }
  }

  // ✅ Expose current user for UI/Receipts
  User? get currentUser => _authUser;

  void _clearStateMemory() {
    _currentCustomer = null;
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _promoDiscount = Decimal.zero;
    // Clear cart in service without notifying yet?
    // actually clearCart() calls notify. We are in a flow.
    _cartService.clearCart();
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
      // Fix 6 Phase 7.1: ใช้ CustomerRepository แทน raw SQL ใน Manager
      try {
        _currentCustomer = await _custRepo.getCustomerById(custId);
      } catch (e) {
        debugPrint('⚠️ [PosState] _loadCartFromPrefs customer error: $e');
        _currentCustomer = null;
      }
    } else {
      _currentCustomer = null;
    }

    _billDiscount = prefs.getDouble('${prefix}cart_discount') ?? 0.0;
    _isPercentDiscount =
        prefs.getBool('${prefix}cart_is_percent_discount') ?? false;

    await _cartService.loadCartFromPrefs((loadedItems) {
      // Optionally do validation or recalc here
    }, userId: _authUser?.id.toString());
    // The listener will trigger notify
  }

  // --- Held Bills ---
  Future<void> _loadHeldBillsFromDB() async {
    final bills = await _heldBillManager.loadHeldBills();
    _heldBills.clear();
    _heldBills.addAll(bills);
    notifyListeners();
  }

  Future<void> holdCurrentBill({String note = ''}) async {
    if (cart.isEmpty) return;
    try {
      await _heldBillManager.holdBill(
          cart: cart, currentCustomer: _currentCustomer, note: note);

      await clearCart(returnStock: false);
      await _loadHeldBillsFromDB();
    } catch (e) {
      debugPrint('Error holding bill: $e');
      rethrow;
    }
  }

  /// Checks stock availability for a held bill.
  /// Returns a list of warnings if stock is insufficient.
  Future<List<String>> checkHeldBillStock(int index) async {
    if (index < 0 || index >= _heldBills.length) return [];
    final heldBill = _heldBills[index];
    final warnings = <String>[];

    try {
      // ✅ Optimized: Batch fetch all products at once
      final productIds = heldBill.items.map((item) => item.productId).toList();
      final products = await _productRepo.getProductsByIds(productIds);

      // Create a map for quick lookup
      final productMap = {for (var p in products) p.id: p};

      // Check stock for each item
      for (var item in heldBill.items) {
        final p = productMap[item.productId];
        if (p != null) {
          if (p.stockQuantity < item.quantity.toDouble()) {
            warnings.add(
                '- ${p.name}\n  (ต้องการ: ${item.quantity.toStringAsFixed(0)}, มี: ${p.stockQuantity.toStringAsFixed(0)})');
          }
        } else {
          // Product not found - might be deleted
          warnings.add('- สินค้ารหัส ${item.productId} ไม่พบในระบบ');
        }
      }
    } catch (e) {
      debugPrint('Error checking stock for held bill: $e');
    }

    return warnings;
  }

  /// Recalls the bill (removes from held_bills and puts into cart)
  /// Should be called after checkHeldBillStock returns empty or user confirms.
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

    // ✅ Optimized: Update local state instead of reloading from DB
    _heldBills.removeAt(index);
    notifyListeners();
    // CartService listener also handles notification, but we need to notify for _heldBills change
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

  // Fix 2 Phase 7.1: Delegate getters ผ่าน LastOrderInfo model
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

  // Fix 5 Phase 7.1: เปลี่ยนชื่อจาก `total` → `subtotalBeforeDiscount` เพื่อความชัดเจน
  // (ยังคง expose `total` เพื่อ backward compatibility กับ UI ที่ยังใช้อยู่)
  double get subtotalBeforeDiscount =>
      cart.fold(Decimal.zero, (sum, item) => sum + item.total).toDouble();
  double get total => subtotalBeforeDiscount; // backward compat

  VatType _vatType = VatType.none;
  VatType get vatType => _vatType;

  void setVatType(VatType type) {
    _vatType = type;
    _invalidateCalcCache(); // Fix 1
    notifyListeners();
  }

  // Fix 1 Phase 7.1: Cache ผลคำนวณ — ป้องกันคำนวณซ้ำหลายรอบต่อ widget build
  void _invalidateCalcCache() => _calcCache = null;

  PriceCalculationResult get _calcResult {
    return _calcCache ??= _priceCalcService.calculateTotals(
      cart: cart,
      billDiscountVal: _billDiscount,
      isPercentDiscount: _isPercentDiscount,
      promoDiscountVal: _promoDiscount.toDouble(),
      pointDiscountAmount: pointDiscountAmount, // ✅ แต้มสะสม
      vatType: _vatType,
      customer: _currentCustomer,
      tier: currentTier,
      roundingMode: _roundingMode,
    );
  }

  double get vatAmount => _calcResult.vatAmount.toDouble();
  double get grandTotal {
    final base = _calcResult.grandTotal.toDouble();
    final afterCoupon = base - _couponDiscountAmount;
    return afterCoupon < 0 ? 0 : afterCoupon; // ไม่ให้ติดลบ
  }
  double get discountAmount =>
      _calcResult.billDiscountAmount.toDouble() +
      _promoDiscount.toDouble() +
      pointDiscountAmount +
      _couponDiscountAmount; // ✅ รวมส่วนลดคูปอง

  double get promoDiscount => _promoDiscount.toDouble();

  // ✅ Point Redemption Methods
  void applyPointDiscount(int points) {
    _pointsToRedeem = points;
    _invalidateCalcCache();
    notifyListeners();
  }

  void clearPointDiscount() {
    _pointsToRedeem = 0;
    _invalidateCalcCache();
    notifyListeners();
  }

  // ✅ Coupon Discount Methods (Phase 2)
  void applyCouponDiscount(double amount, String? couponCode) {
    _couponDiscountAmount = amount;
    _appliedCouponCode = couponCode;
    _invalidateCalcCache();
    notifyListeners();
  }

  void clearCouponDiscount() {
    _couponDiscountAmount = 0.0;
    _appliedCouponCode = null;
    _invalidateCalcCache();
    notifyListeners();
  }

  void _calculatePromotions() {
    // Legacy Promo Repo expects List<OrderItem> (with doubles?).
    // If _legacyPricingService uses double, we might need to convert or update it.
    // For now, let's assume _legacyPricingService calculates using double, which might cause mismatch.
    // Ideally we should move promotion calc to PriceCalculationService or update PricingService to use Decimal.
    // But PricingService is a "Legacy" service I didn't verify.
    // Let's rely on the result being "close enough" and stored in Decimal _promoDiscount.

    // Use PriceCalculationService for promotions
    _promoDiscount =
        _priceCalcService.calculatePromotions(cart, _activePromotions);
  }

  Future<bool> shouldAutoPrint() async {
    final localSettings = LocalSettingsService();
    // Fix 2: ใช้ getter ที่ delegate ผ่าน lastPaymentMethod แทน field เก่า
    final pm = lastPaymentMethod.toUpperCase();
    if (pm.contains('CASH') || pm.contains('TRANSFER') || pm.contains('QR')) {
      return await localSettings.getBool('auto_print_receipt',
          defaultValue: false);
    } else {
      // Assuming anything else is Credit/Debt
      return await localSettings.getBool('auto_print_delivery_note',
          defaultValue: false);
    }
  }

  // --- Cart Operations ---
  void selectCustomer(Customer? customer) {
    _currentCustomer = customer;
    _invalidateCalcCache(); // Fix 1
    // Fix 4: ใช้ recalculateAllPrices แทน hack loop
    _cartService.recalculateAllPrices(customer, currentTier);
    _saveCartToPrefs();
    notifyListeners();
  }

  void clearCustomer() {
    _currentCustomer = null;
    _invalidateCalcCache(); // Fix 1
    _cartService.recalculateAllPrices(null, null);
    _saveCartToPrefs();
    notifyListeners();
  }

  void setBillDiscount(double value, {bool isPercent = false}) {
    _billDiscount = value;
    _isPercentDiscount = isPercent;
    _invalidateCalcCache(); // Fix 1
    _saveCartToPrefs();
    notifyListeners();
  }

  Future<void> addProductToCart(Product product,
      {double quantity = 1.0,
      double? overridePrice,
      String? overrideUnit,
      double? overrideConversionFactor}) async {
    // Reset suppression when starting new transaction
    _hardwareService.setSuppressDisplay(false);

    await _cartService.addProduct(
        product: product,
        quantity: Decimal.parse(quantity.toString()),
        overridePrice: overridePrice != null
            ? Decimal.parse(overridePrice.toString())
            : null,
        overrideUnit: overrideUnit,
        overrideConversionFactor: overrideConversionFactor,
        customer: _currentCustomer,
        tier: currentTier);
  }

  Future<void> removeItem(int index) async {
    _cartService.removeItem(index);
  }

  Future<void> updateItemPrice(int index, Decimal newPrice) async {
    _cartService.updateItemPrice(index, newPrice);
  }

  Future<void> updateItemQuantity(int index, Decimal newQuantity) async {
    await _cartService.updateItemQuantity(
        index, newQuantity, _currentCustomer, currentTier);
  }

  void updateItemDiscount(int index, double discountVal,
      {bool isPercent = false}) {
    _cartService.updateItemDiscount(
        index, Decimal.parse(discountVal.toString()),
        isPercent: isPercent);
  }

  void updateItemComment(int index, String comment) {
    _cartService.updateItemComment(index, comment);
  }

  Future<void> clearCart({bool returnStock = false}) async {
    _cartService.clearCart();
    _currentCustomer = null;
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _promoDiscount = Decimal.zero;
    _pointsToRedeem = 0; // ✅ Clear point discount on new transaction

    // Notifications handled by listener
  }

  void _updateDisplay() {
    if (cart.isEmpty && _currentCustomer == null) {
      _hardwareService.showIdle();
    } else {
      _hardwareService.updateCart(grandTotal: grandTotal, items: cart);
    }
  }

  // ✅ Expose update method for Payment Modal
  void updateCustomerDisplay({double received = 0.0, double change = 0.0}) {
    _hardwareService.updateCart(
        grandTotal: grandTotal,
        items: cart,
        received: received,
        change: change);
  }

  Future<void> showPaymentQr(double amount) async {
    final globalSettings = SettingsService();

    // ✅ แก้ไข: อ่าน Mode จาก Global Settings (MySQL)
    final mode = globalSettings.getString('payment_qr_mode') ?? 'dynamic';

    String qrData = '';
    if (mode == 'dynamic') {
      final promptPayId = globalSettings.promptPayId;
      if (promptPayId.isNotEmpty) {
        qrData = PromptPayHelper.generatePayload(promptPayId, amount: amount);
      }
    }
    // ถ้าเป็น static มันจะไปใช้อีกตัวแปรในหน้าจอลูก (CustomerDisplayScreen โหลดเอง)

    await _hardwareService.showQrCode(
      qrData: qrData,
      amount: amount,
      total: grandTotal,
      items: cart,
    );
  }

  void resetDisplay() {
    _updateDisplay();
  }

  final OrderProcessingService _orderService = OrderProcessingService();

  Future<int> saveOrder({
    required List<PaymentRecord> payments,
    DeliveryType deliveryType = DeliveryType.none,
    String? note, // ✅ Added Note
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
        pointsUsed: _pointsToRedeem, // ✅ ส่งแต้มที่แลก
        activePromotions: _activePromotions, // ✅ ส่ง active promotions ไปดู bonus_points
        currentTier: currentTier, // ✅ ส่ง tier ไปคูณแต้ม / x3 วันเกิด
      );

      final currentItems = List<OrderItem>.from(cart);
      final currentCust = _currentCustomer;
      final currentTotal = grandTotal;
      double received = payments.fold(0.0, (sum, p) => sum + p.amount);
      final currentChange = (received - grandTotal).clamp(0.0, double.infinity);
      String paymentMethodStr = payments.map((p) => p.method).join(',');

      // ✅ Phase 2: Mark Coupon as USED if applied
      if (_appliedCouponCode != null) {
        try {
          final rewardRepo = RewardRepository();
          await rewardRepo.useCoupon(_appliedCouponCode!, orderId);
        } catch (e) {
          debugPrint('⚠️ Error marking coupon as used: $e');
        }
      }

      // Fix 2 Phase 7.1: รวมข้อมูลออเดอร์ล่าสุดใน LastOrderInfo model เดียว
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

      // -------------------------------------------------------------
      // ✅ FIX: Auto-Create Delivery Job if Delivery is selected
      // -------------------------------------------------------------
      // -------------------------------------------------------------
      // ✅ FIX: Auto-Create Delivery Job (Backgrounded to prevent UI Freeze)
      // -------------------------------------------------------------
      if (deliveryType == DeliveryType.delivery ||
          deliveryType == DeliveryType.pickup) {
        // Fire and Forget - Prevent blocking the UI
        _processDeliveryJobInBackground(
          orderId,
          deliveryType,
          currentCust,
          currentItems,
          grandTotal,
          received,
          discountAmount,
          vatAmount,
          payments, // Pass payments to determine note
          manualNote: note, // ✅ Pass Manual Note
        );
      }
      // -------------------------------------------------------------
      // -------------------------------------------------------------

      // ✅ Hardware Integration via Service
      _hardwareService
          .openDrawer()
          .catchError((e) => debugPrint('Drawer Error: $e'));

      // 1. Enable Suppression to prevent Idle screen via listener
      _hardwareService.setSuppressDisplay(true);

      // 2. Clear Cart + Coupon state (listener triggers but _updateDisplay returns early/is suppressed)
      await clearCart(returnStock: false);
      _couponDiscountAmount = 0.0;
      _appliedCouponCode = null;
      _pointsToRedeem = 0;

      // 3. Show Success Screen (Persist)
      await _hardwareService.showSuccess(
        received: received,
        change: currentChange,
        total: grandTotal,
        items: currentItems,
      );

      // --- Line OA Push Receipt ---
      // ✅ ปิดไว้ เพราะ payment_modal._sendLineNotifications
      // รับผิดชอบส่งทั้งข้อความ (push-receipt) และรูป (push-receipt-image) แล้ว
      // หากปล่อยให้ทั้งสองส่ง จะทำให้ข้อความ duplicate

      return orderId;
    } catch (e) {
      debugPrint('Save Order Delegated Error: $e');
      rethrow;
    }
  }

  Future<void> sendToDeliveryFromHistory(int orderId,
      {String jobType = 'delivery'}) async {
    // Fix 3 Phase 7.1: ใช้ SalesRepository แทน raw SQL ใน Manager
    final data = await _salesRepo.getOrderForDelivery(orderId);
    if (data == null) throw Exception('บิล #$orderId ไม่พบข้อมูล');

    final orderData = data['orderData'] as Map<String, dynamic>;
    final itemsData = data['items'] as List<Map<String, dynamic>>;

    // ✅ Fix: Allow General Customer (Walk-in)
    final customer = orderData['customerId'] != null
        ? Customer.fromJson({
            ...orderData,
            'id': orderData['customerId'],
          })
        : Customer(
            id: 0,
            memberCode: 'GENERAL',
            currentPoints: 0,
            firstName: 'ลูกค้า',
            lastName: 'ทั่วไป (Walk-in)',
            phone: orderData['phone']?.toString() ?? '',
            address: orderData['address']?.toString() ?? '',
          );

    final List<OrderItem> items =
        itemsData.map((row) => OrderItem.fromJson(row)).toList();

    final gTotal = double.tryParse(orderData['grandTotal'].toString()) ?? 0.0;
    final received =
        double.tryParse(orderData['received']?.toString() ?? '0') ?? 0.0;
    final String? pm = orderData['paymentMethod']?.toString();

    // ✅ Logic: Note Generation matching saveOrder
    String deliveryNote = '';
    final bool isCredit = pm != null &&
        (pm.toUpperCase().contains('CREDIT') ||
            pm.contains('เงินเชื่อ') ||
            pm.contains('ลงบัญชี'));

    if (!isCredit && received >= gTotal - 0.01) {
      deliveryNote = '✅ จ่ายเงินแล้ว (Paid)';
    } else {
      deliveryNote = '📝 ลงบัญชี/เก็บปลายทาง (COD/Credit)';
    }

    // ✅ Add specific note for Back Shop / Pickup
    if (jobType == 'customer_pickup' || jobType == 'pickup') {
      deliveryNote += ' (รับเองที่ร้าน)';
    }

    final billPdfData = await ReceiptService().generateDeliveryNoteData(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: double.tryParse(orderData['discount']?.toString() ?? '0') ?? 0,
      vatAmount:
          double.tryParse(orderData['vatAmount']?.toString() ?? '0') ?? 0.0,
      grandTotalOverride: gTotal,
    );

    // ✅ Fix: Clear address for Pickup jobs to prevent showing in Delivery Tab
    Customer effectiveCustomer = customer;
    if (jobType == 'pickup' || jobType == 'customer_pickup') {
      effectiveCustomer = Customer(
        id: customer.id,
        firstName: customer.firstName,
        lastName: customer.lastName,
        phone: customer.phone,
        currentPoints: customer.currentPoints,
        memberCode: customer.memberCode,
        address: '', // Clear Address
        shippingAddress: '', // Clear Shipping Address
        firebaseUid: customer.firebaseUid,
        lineUserId: customer.lineUserId, // ✅ Fix: Preserve Line User ID
      );
    }

    await _deliveryService.createDeliveryJob(
        orderId: orderId,
        customer: effectiveCustomer,
        items: items,
        grandTotal: gTotal,
        isManual: true,
        note: deliveryNote,
        billPdfData: billPdfData,
        jobType: jobType,
        paymentMethod: isCredit ? 'credit' : 'cash', // ✅ Pass paymentMethod
        vatAmount:
            double.tryParse(orderData['vatAmount']?.toString() ?? '0') ?? 0.0);
  }

  // --- Barcode / Product Scanning Logic ---
  Future<ScanResult> handleBarcode(String barcode,
      {double quantity = 1.0}) async {
    if (barcode.isEmpty) {
      return ScanResult(status: ScanStatus.error, message: 'Barcode is empty');
    }

    final normalized = BarcodeUtils.fixThaiInput(barcode.trim());

    // 1. Search Logic
    try {
      final matches = await _productRepo.getProductsPaginated(1, 10,
          searchTerm: normalized);

      // 2. Exact Match Check
      Product? exactMatch;
      try {
        exactMatch = matches.firstWhere((p) => p.barcode == normalized);
      } catch (_) {}

      // 3. Multi-unit Check (if no exact main match)
      if (exactMatch == null) {
        // ✅ Optimized: Query exact barcode instead of fetching ALL rows
        final match = await _productRepo.findProductBarcode(normalized);
        if (match != null) {
          try {
            final pId = match['productId'] as int;
            final baseProduct = await _productRepo.getProductById(pId);

            if (baseProduct != null) {
              final price = double.tryParse(match['price'].toString()) ?? 0.0;
              final unit = match['unitName'].toString();
              final factor =
                  double.tryParse(match['quantity'].toString()) ?? 1.0;

              await addProductToCart(baseProduct,
                  quantity: quantity,
                  overridePrice: price,
                  overrideUnit: unit,
                  overrideConversionFactor: factor);

              return ScanResult(
                  status: ScanStatus.success, product: baseProduct);
            }
          } catch (_) {}
        }
      }

      // 4. Handle Results
      if (exactMatch != null) {
        if (isWeighingProduct(exactMatch)) {
          return ScanResult(
              status: ScanStatus.requiresWeight, product: exactMatch);
        }
        await addProductToCart(exactMatch, quantity: quantity);
        return ScanResult(status: ScanStatus.success, product: exactMatch);
      } else if (matches.isNotEmpty) {
        if (matches.length == 1) {
          final p = matches.first;
          if (isWeighingProduct(p)) {
            return ScanResult(status: ScanStatus.requiresWeight, product: p);
          }
          await addProductToCart(p, quantity: quantity);
          return ScanResult(status: ScanStatus.success, product: p);
        } else {
          // Multiple matches
          return ScanResult(
              status: ScanStatus.multipleMatches, matches: matches);
        }
      } else {
        return ScanResult(status: ScanStatus.notFound);
      }
    } catch (e) {
      debugPrint('Scan Error: $e');
      return ScanResult(status: ScanStatus.error, message: e.toString());
    }
  }

  // Expose Product Repo Search for UI dialogs
  Future<List<Product>> searchProducts(String term) async {
    return await _productRepo.getProductsPaginated(1, 50, searchTerm: term);
  }

  // Create Product helper
  Future<int> createNewProduct(Product product) async {
    return await _productRepo.saveProduct(product);
  }

  // Quick Sale Helper (Temp Product)
  Future<void> addQuickSaleItem(
      {required String name,
      required double price,
      double quantity = 1.0}) async {
    final tempProduct = Product(
        id: -999,
        name: name,
        barcode: '', // No barcode for quick sale usually, or use a dummy
        retailPrice: price,
        costPrice: 0,
        productType: 0,
        stockQuantity: 0,
        trackStock: false,
        points: 0);
    await addProductToCart(tempProduct, quantity: quantity);
  }

  // ✅ Background Delivery Job Processing

  Future<void> _processDeliveryJobInBackground(
    int orderId,
    DeliveryType deliveryType,
    Customer? currentCust,
    List<OrderItem> currentItems,
    double grandTotal,
    double received,
    double discountAmount,
    double vatAmount,
    List<PaymentRecord> payments, {
    String? manualNote, // ✅ Added manual note
  }) async {
    try {
      debugPrint(
          '⏳ [Background] Processing Delivery Job for Order #$orderId...');

      // Fallback for General Customer (Walk-in)
      Customer effectiveCustomer = currentCust ??
          Customer(
              id: 0,
              memberCode: 'GENERAL',
              currentPoints: 0,
              firstName: 'ลูกค้า',
              lastName: 'ทั่วไป (Walk-in)',
              phone: '');

      // REFRESH CUSTOMER DATA
      if (effectiveCustomer.id > 0) {
        try {
          final freshData =
              await _custRepo.getCustomerById(effectiveCustomer.id);
          if (freshData != null) {
            effectiveCustomer = freshData;
          }
        } catch (e) {
          debugPrint('⚠️ Failed to refresh customer data: $e');
        }
      }

      // 1. Generate PDF Data
      final pdfData = await ReceiptService().generateDeliveryNoteData(
        orderId: orderId,
        items: currentItems,
        customer: effectiveCustomer,
        discount: discountAmount,
        vatAmount: vatAmount,
        grandTotalOverride: grandTotal,
        pageFormatOverride: PdfPageFormat(
            22.86 * PdfPageFormat.cm, 13.97 * PdfPageFormat.cm,
            marginAll: 0), // ✅ Legacy A5 Horizontal (9x5.5")
      );

      // 2. Determine Note
      String note = '';
      final bool isCredit = payments.any((p) =>
          p.method.toUpperCase().contains('CREDIT') ||
          p.method.contains('เงินเชื่อ') ||
          p.method.contains('ลงบัญชี'));

      if (!isCredit && received >= grandTotal - 0.01) {
        note = '✅ จ่ายเงินแล้ว (Paid)';
      } else {
        note = '📝 ลงบัญชี/เก็บปลายทาง (COD/Credit)';
      }

      if (deliveryType == DeliveryType.pickup) {
        note = '$note (รับเองที่ร้าน)';
      }

      // ✅ Append Manual Note
      if (manualNote != null && manualNote.isNotEmpty) {
        note += '\nหมายเหตุ: $manualNote';
      }

      // 3. Create Job
      await _deliveryService.createDeliveryJob(
        orderId: orderId,
        customer: effectiveCustomer,
        items: currentItems,
        grandTotal: grandTotal,
        isManual: false,
        note: note,
        billPdfData: pdfData,
        vatAmount: vatAmount,
        paymentMethod: isCredit ? 'credit' : 'cash', // ✅ Pass paymentMethod
        jobType: deliveryType == DeliveryType.pickup
            ? 'pickup'
            : 'delivery',
      );

      debugPrint('✅ [Background] Delivery Job for Order #$orderId created.');
    } catch (e) {
      debugPrint('⚠️ [Background] Auto Delivery Job Creation Failed: $e');
    }
  }

  // Helper to check if product requires weighing
  bool isWeighingProduct(Product product) {
    // Check if ID is in the set of weighing types
    // return _weighingTypeIds.contains(product.productType);
    return false; // ✅ Disable Weighing Logic
  }
}
