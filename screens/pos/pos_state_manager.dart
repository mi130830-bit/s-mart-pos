import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import 'package:decimal/decimal.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/order_item.dart';
import '../../models/payment_record.dart';
import '../../models/member_tier.dart';
import '../../models/promotion.dart';
import '../../services/mysql_service.dart';
import '../../repositories/promotion_repository.dart';
import '../../services/firebase_service.dart';
import '../../services/customer_display_service.dart';
import '../../services/printing/receipt_service.dart';
import '../../repositories/customer_repository.dart';
import '../../utils/promptpay_helper.dart';
import '../../services/sales/order_processing_service.dart';
import '../../models/delivery_type.dart';
import '../../services/sales/held_bill_manager.dart';

import '../../services/settings_service.dart';
import '../../services/local_settings_service.dart';

// New Services
import '../../services/sales/price_calculation_service.dart';
import '../../services/sales/cart_service.dart';
import '../../services/integration/delivery_integration_service.dart';

import '../../repositories/product_repository.dart';
import '../../utils/thai_helper.dart';
import '../../repositories/product_type_repository.dart'; // Added

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
  final MySQLService _dbService = MySQLService();
  final FirebaseService _firebaseService = FirebaseService();

  final PriceCalculationService _priceCalcService = PriceCalculationService();
  late CartService _cartService;
  late DeliveryIntegrationService _deliveryService;

  Customer? _currentCustomer;
  // We expose cart from CartService, but maybe wrapped or direct
  List<OrderItem> get cart => _cartService.cart;

  final HeldBillManager _heldBillManager = HeldBillManager();
  // Old pricing service kept for legacy getters if needed? Or replaced?
  // Let's rely on _priceCalcService for calculation getters.

  final List<HeldBill> _heldBills = [];

  double _billDiscount = 0.0;
  bool _isPercentDiscount = false;

  // Last Order Cache
  List<OrderItem> _lastSoldItems = [];
  Customer? _lastSoldCustomer;
  int _lastOrderId = 0;
  double _lastGrandTotal = 0.0;
  double _lastReceived = 0.0;
  double _lastChange = 0.0;
  String _lastPaymentMethod = '';
  double _lastDiscountAmount = 0.0;
  List<PaymentRecord> _lastPayments = [];
  DateTime? _lastOrderTime;

  // CRM - Tiers
  List<MemberTier> _tiers = [];
  final CustomerRepository _custRepo = CustomerRepository();
  final ProductRepository _productRepo = ProductRepository();
  final ProductTypeRepository _typeRepo = ProductTypeRepository(); // Added
  Set<int> _weighingTypeIds = {1}; // Default system weighing ID

  // Promotions
  List<Promotion> _activePromotions = [];
  final PromotionRepository _promoRepo = PromotionRepository();

  // Cache for calculation results
  Decimal _promoDiscount = Decimal.zero;

  final int _currentBranchId = 1;
  int get currentBranchId => _currentBranchId;
  String _shopName = 'S-Link POS';
  String get shopName => _shopName;
  bool _allowNegativeStock = true;

  PosStateManager() {
    _cartService = CartService(_dbService, _priceCalcService);
    _deliveryService = DeliveryIntegrationService(_dbService, _firebaseService);

    // Listen to CartService to propagate notifications
    _cartService.addListener(() {
      _calculatePromotions();
      _updateDisplay();
      _saveCartToPrefs();
      notifyListeners();
    });

    _init();
  }

  Future<void> _init() async {
    await _custRepo.initMemberTierTable();
    _tiers = await _custRepo.getAllTiers();

    // Load Weighing Type IDs logic
    _weighingTypeIds = await _typeRepo.getWeighingTypeIds();

    await _promoRepo.initTable();
    _activePromotions = await _promoRepo.getAllPromotions(activeOnly: true);

    await _loadCartFromPrefs();
    await _loadHeldBillsFromDB();
    refreshGeneralSettings();
    // Auto-open Customer Display if needed/connected
    CustomerDisplayService().openDisplay();
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
    _cartService.setAllowNegativeStock(_allowNegativeStock);
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
      if (!_dbService.isConnected()) await _dbService.connect();
      final results = await _dbService
          .query('SELECT * FROM customer WHERE id = :id', {'id': custId});
      if (results.isNotEmpty) {
        _currentCustomer = Customer.fromJson(results.first);
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

  Future<void> recallBill(int index) async {
    if (index < 0 || index >= _heldBills.length) return;
    final heldBill = _heldBills[index];

    if (heldBill.id != null) {
      await _heldBillManager.removeBillRecord(heldBill.id!);
    }

    _currentCustomer = heldBill.customer;
    _cartService.setCart(heldBill.items);
    _billDiscount = 0.0;
    _isPercentDiscount = false;

    await _saveCartToPrefs();
    await _loadHeldBillsFromDB();
    // notifyListeners(); // CartService listener handles it
  }

  Future<void> deleteHeldBill(int index) async {
    final heldBill = _heldBills[index];
    await _heldBillManager.deleteHeldBill(heldBill);
    await _loadHeldBillsFromDB();
  }

  // --- Getters ---
  Customer? get currentCustomer => _currentCustomer;
  List<HeldBill> get heldBills => List.unmodifiable(_heldBills);
  double get billDiscount => _billDiscount;
  bool get isPercentDiscount => _isPercentDiscount;

  List<OrderItem> get lastSoldItems => List.unmodifiable(_lastSoldItems);
  Customer? get lastSoldCustomer => _lastSoldCustomer;
  int get lastOrderId => _lastOrderId;
  double get lastGrandTotal => _lastGrandTotal;
  double get lastReceived => _lastReceived;
  double get lastChange => _lastChange;
  String get lastPaymentMethod => _lastPaymentMethod;
  double get lastDiscountAmount => _lastDiscountAmount;
  List<PaymentRecord> get lastPayments => List.unmodifiable(_lastPayments);
  DateTime? get lastOrderTime => _lastOrderTime;

  MemberTier? get currentTier {
    if (_currentCustomer == null || _currentCustomer!.tierId == null) {
      return null;
    }
    return _tiers.firstWhere((t) => t.id == _currentCustomer!.tierId,
        orElse: () => MemberTier(id: 0, name: 'Standard'));
  }

  double get total =>
      cart.fold(Decimal.zero, (sum, item) => sum + item.total).toDouble();

  VatType _vatType = VatType.none;
  VatType get vatType => _vatType;

  void setVatType(VatType type) {
    _vatType = type;
    notifyListeners();
  }

  // --- Calculation Getters (Delegated) ---

  PriceCalculationResult get _calcResult => _priceCalcService.calculateTotals(
        cart: cart,
        billDiscountVal: _billDiscount,
        isPercentDiscount: _isPercentDiscount,
        promoDiscountVal: _promoDiscount.toDouble(),
        vatType: _vatType,
        customer: _currentCustomer,
        tier: currentTier,
      );

  double get vatAmount => _calcResult.vatAmount.toDouble();
  double get grandTotal => _calcResult.grandTotal.toDouble();
  double get discountAmount =>
      _calcResult.billDiscountAmount.toDouble() +
      _promoDiscount.toDouble(); // Or from CalcResult?
  // Note: legacy discountAmount usually included promo + bill.
  // calcResult.billDiscountAmount is just bill.

  double get promoDiscount => _promoDiscount.toDouble();

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
    if (_lastPaymentMethod.toUpperCase().contains('CASH') ||
        _lastPaymentMethod.toUpperCase().contains('TRANSFER') ||
        _lastPaymentMethod.toUpperCase().contains('QR')) {
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
    // Trigger re-calc of prices (member tiers etc)
    // We need to iterate entire cart and re-add/update?
    // Or just method in CartService to RefreshPrices(customer, tier)
    // _cartService.recalculateAll(customer, currentTier); -> Not implemented yet.
    // We can iterate manually for now or implement in CartService.
    _refreshCartPrices();

    _saveCartToPrefs();
    notifyListeners();
  }

  void clearCustomer() {
    _currentCustomer = null;
    _refreshCartPrices();
    _saveCartToPrefs();
    notifyListeners();
  }

  void _refreshCartPrices() {
    // Quick hack: Loop and update qty (which triggers price recalc)
    for (int i = 0; i < cart.length; i++) {
      _cartService.updateItemQuantity(
          i, cart[i].quantity, _currentCustomer, currentTier);
    }
  }

  void setBillDiscount(double value, {bool isPercent = false}) {
    _billDiscount = value;
    _isPercentDiscount = isPercent;
    _saveCartToPrefs();
    notifyListeners();
  }

  Future<void> addProductToCart(Product product,
      {double quantity = 1.0,
      double? overridePrice,
      String? overrideUnit,
      double? overrideConversionFactor}) async {
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

  Future<void> updateItemPrice(int index, double newPrice) async {
    _cartService.updateItemPrice(index, Decimal.parse(newPrice.toString()));
  }

  Future<void> updateItemQuantity(int index, double newQuantity) async {
    _cartService.updateItemQuantity(index,
        Decimal.parse(newQuantity.toString()), _currentCustomer, currentTier);
  }

  void updateItemDiscount(int index, double discountVal,
      {bool isPercent = false}) {
    // Needs implementation in CartService
    // _cartService.updateItemDiscount(...)
  }

  void updateItemComment(int index, String comment) {
    // Needs implementation in CartService
  }

  Future<void> clearCart({bool returnStock = false}) async {
    _cartService.clearCart();
    _currentCustomer = null;
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _promoDiscount = Decimal.zero;

    // Notifications handled by listener
  }

  void _updateDisplay() {
    final service = CustomerDisplayService();
    if (service.isOpen) {
      if (cart.isEmpty && _currentCustomer == null) {
        service.showIdle();
      } else {
        service.updateCart(total: grandTotal, items: cart);
      }
    }
  }

  // ✅ Expose update method for Payment Modal
  void updateCustomerDisplay({double received = 0.0, double change = 0.0}) {
    final service = CustomerDisplayService();
    if (service.isOpen) {
      service.updateCart(
          total: grandTotal, items: cart, received: received, change: change);
    }
  }

  Future<void> showPaymentQr(double amount) async {
    final service = CustomerDisplayService();
    // ❌ เอาออก: ไม่เช็ค isOpen แล้ว เขียนไฟล์โลด (เผื่อ Window ID หลุด)
    // if (!service.isOpen) return;

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

    await service.showQrCode(
      qrData: qrData,
      amount: amount,
      total: grandTotal,
      items: cart,
      received: amount, // For QR, we assume received = amount usually
      change: 0.0,
    );
  }

  void resetDisplay() {
    _updateDisplay();
  }

  final OrderProcessingService _orderService = OrderProcessingService();

  Future<int> saveOrder({
    required List<PaymentRecord> payments,
    DeliveryType deliveryType = DeliveryType.none,
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
      );

      final currentItems = List<OrderItem>.from(cart);
      final currentCust = _currentCustomer;
      final currentTotal = grandTotal;
      double received = payments.fold(0.0, (sum, p) => sum + p.amount);
      final currentChange = (received - grandTotal).clamp(0.0, double.infinity);
      String paymentMethodStr = payments.map((p) => p.method).join(',');

      _lastOrderId = orderId;
      _lastSoldItems = currentItems;
      _lastSoldCustomer = currentCust;
      _lastGrandTotal = currentTotal;
      _lastReceived = received;
      _lastChange = currentChange;
      _lastPaymentMethod = paymentMethodStr;
      _lastDiscountAmount = discountAmount;
      _lastPayments = payments;
      _lastOrderTime = DateTime.now();

      // -------------------------------------------------------------
      // ✅ FIX: Auto-Create Delivery Job if Delivery is selected
      // -------------------------------------------------------------
      if (deliveryType == DeliveryType.delivery ||
          deliveryType == DeliveryType.pickup) {
        // Fallback for General Customer (Walk-in)
        final effectiveCustomer = currentCust ??
            Customer(
                id: 0,
                memberCode: 'GENERAL',
                currentPoints: 0,
                firstName: 'ลูกค้า',
                lastName: 'ทั่วไป (Walk-in)',
                phone: '');

        try {
          // 1. Generate PDF Data for App (Bill Image)
          final pdfData = await ReceiptService().generateDeliveryNoteData(
            orderId: orderId,
            items: currentItems,
            customer: effectiveCustomer,
            discount: discountAmount,
          );

          // 2. Determine Note based on Payment
          String note = '';
          final bool isCredit = payments.any((p) =>
              p.method.toUpperCase().contains('CREDIT') ||
              p.method.contains('เงินเชื่อ') ||
              p.method.contains('ลงบัญชี'));

          if (received >= grandTotal - 0.01) {
            note = '✅ จ่ายเงินแล้ว (Paid)';
          } else if (isCredit) {
            note = '📝 ลงบัญชี (Credit)';
          } else {
            final due = grandTotal - received;
            note = 'เก็บเงินปลายทาง ${due.toStringAsFixed(2)} บาท';
          }

          if (deliveryType == DeliveryType.pickup) {
            note = '$note (รับเองที่ร้าน)';
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
            jobType: deliveryType == DeliveryType.pickup
                ? 'customer_pickup'
                : 'delivery',
          );
        } catch (e) {
          debugPrint('⚠️ Auto Delivery Job Creation Failed: $e');
          // We do not rethrow here to avoid rolling back the valid SQL Order.
        }
      }
      // -------------------------------------------------------------

      ReceiptService()
          .openDrawer()
          .catchError((e) => debugPrint('Drawer Error: $e'));

      // Show Success on Customer Display
      CustomerDisplayService().showSuccess();

      await clearCart(returnStock: false);
      return orderId;
    } catch (e) {
      debugPrint('Save Order Delegated Error: $e');
      rethrow;
    }
  }

  Future<void> sendToDeliveryFromHistory(int orderId) async {
    // Delegate to service
    if (!_dbService.isConnected()) await _dbService.connect();

    // Need to fetch data first? `DeliveryIntegrationService` takes clean args, not ID?
    // Actually `DeliveryIntegrationService` was designed to check ID...
    // Re-reading my code for `DeliveryIntegrationService`: it takes `orderId`, `customer`, `items` etc.
    // So I still need to fetch logic here OR move fetch logic to service.
    // I'll keep fetch logic here (copied from previous) then call service.

    final sqlOrder = '''
        SELECT o.*, c.*, o.id AS orderId, c.id AS customerId
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.id = :id
      ''';
    final orderRes = await _dbService.query(sqlOrder, {'id': orderId});
    if (orderRes.isEmpty) throw Exception('บิล #$orderId ไม่พบข้อมูล');

    final orderData = orderRes.first;
    if (orderData['customerId'] == null) {
      throw Exception(
          'บิล #$orderId ไม่มีข้อมูลลูกค้า (ต้องมีลูกค้าเพื่อส่งของ)');
    }

    final itemsRes = await _dbService.query(
      'SELECT * FROM orderitem WHERE orderId = :id',
      {'id': orderId},
    );
    final List<OrderItem> items =
        itemsRes.map((row) => OrderItem.fromJson(row)).toList();

    final customer = Customer.fromJson({
      ...orderData,
      'id': orderData['customerId'],
    });

    final gTotal = double.tryParse(orderData['grandTotal'].toString()) ?? 0.0;
    final String? pm = orderData['paymentMethod']?.toString();
    String? deliveryNote;
    if (pm != null && (pm.toUpperCase().contains('CASH') || pm == 'เงินสด')) {
      deliveryNote = '✅ จ่ายเงินแล้ว (Cash Paid)';
    }

    final billPdfData = await ReceiptService().generateDeliveryNoteData(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: double.tryParse(orderData['discount']?.toString() ?? '0') ?? 0,
    );

    await _deliveryService.createDeliveryJob(
        orderId: orderId,
        customer: customer,
        items: items,
        grandTotal: gTotal,
        isManual: true,
        note: deliveryNote,
        billPdfData: billPdfData);
  }

  // --- Barcode / Product Scanning Logic ---
  Future<ScanResult> handleBarcode(String barcode,
      {double quantity = 1.0}) async {
    if (barcode.isEmpty) {
      return ScanResult(status: ScanStatus.error, message: 'Barcode is empty');
    }

    final normalized = ThaiHelper.normalizeBarcode(barcode.trim());

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
        final extraBarcodes = await _productRepo.getAllProductBarcodes();
        try {
          final match =
              extraBarcodes.firstWhere((e) => e['barcode'] == normalized);
          final pId = match['productId'] as int;
          final baseProduct = await _productRepo.getProductById(pId);

          if (baseProduct != null) {
            final price = double.tryParse(match['price'].toString()) ?? 0.0;
            final unit = match['unitName'].toString();
            final factor = double.tryParse(match['quantity'].toString()) ?? 1.0;

            await addProductToCart(baseProduct,
                quantity: quantity,
                overridePrice: price,
                overrideUnit: unit,
                overrideConversionFactor: factor);

            return ScanResult(status: ScanStatus.success, product: baseProduct);
          }
        } catch (_) {}
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

  // Helper to check if product requires weighing
  bool isWeighingProduct(Product product) {
    // Check if ID is in the set of weighing types
    return _weighingTypeIds.contains(product.productType);
  }
}
