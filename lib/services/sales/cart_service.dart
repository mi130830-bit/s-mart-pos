// ignore_for_file: unused_field
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../models/product_price_tier.dart';
import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../repositories/product_price_tier_repository.dart';
import '../mysql_service.dart';
import '../settings_service.dart'; // ✅ Added
import 'price_calculation_service.dart';

class CartService extends ChangeNotifier {
  final MySQLService _dbService;
  final ProductPriceTierRepository _tierRepo;
  final PriceCalculationService _priceService;

  List<OrderItem> _cart = [];
  List<OrderItem> get cart => List.unmodifiable(_cart);

  bool _allowNegativeStock = true;

  CartService(this._dbService, this._priceService,
      {ProductPriceTierRepository? tierRepo})
      : _tierRepo = tierRepo ?? ProductPriceTierRepository();

  void setAllowNegativeStock(bool allow) {
    _allowNegativeStock = allow;
  }

  // --- Persistence ---
  Future<void> saveCartToPrefs(
      {int? customerId,
      double discountVal = 0,
      bool isPercent = false,
      String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = userId != null ? '${userId}_' : '';

    if (_cart.isEmpty && customerId == null) {
      await prefs.remove('${prefix}cart_items');
      await prefs.remove('${prefix}cart_customer_id');
      await prefs.remove('${prefix}cart_discount');
      await prefs.remove('${prefix}cart_is_percent_discount');
      return;
    }

    final String cartJson =
        jsonEncode(_cart.map((item) => item.toJson()).toList());
    await prefs.setString('${prefix}cart_items', cartJson);

    if (customerId != null) {
      prefs.setInt('${prefix}cart_customer_id', customerId);
    } else {
      await prefs.remove('${prefix}cart_customer_id');
    }

    await prefs.setDouble('${prefix}cart_discount', discountVal);
    await prefs.setBool('${prefix}cart_is_percent_discount', isPercent);
  }

  Future<void> loadCartFromPrefs(Function(List<OrderItem>) onLoaded,
      {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = userId != null ? '${userId}_' : '';

      final String? cartJson = prefs.getString('${prefix}cart_items');
      if (cartJson != null) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        _cart = decoded.map((item) => OrderItem.fromJson(item)).toList();
        onLoaded(_cart);
        notifyListeners();
      } else {
        // Clear if not found (switched user with empty cart)
        _cart = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart from prefs: $e');
    }
  }

  // --- CRUD ---

  Future<void> addProduct({
    required Product product,
    required Decimal quantity,
    Decimal? overridePrice,
    String? overrideUnit,
    double? overrideConversionFactor,
    Customer? customer,
    MemberTier? tier,
  }) async {
    final factor = overrideConversionFactor ?? 1.0;

    // 1. Stock Check
    if (product.trackStock) {
      // ✅ ใช้สต็อกที่อัปเดตอิงกับ Online/Composite ที่ผูกมากับ object Product ได้เลย (แทนการไป query raw DB ซึ่งทำให้สินค้าประกอบได้ค่าเป็น 0)
      final current = Decimal.parse(product.stockQuantity.toString());
      final needed = quantity * Decimal.parse(factor.toString());

      Decimal alreadyInCart = Decimal.zero;
      for (var item in _cart) {
        if (item.productId == product.id) {
          alreadyInCart += (item.quantity *
              Decimal.parse(item.conversionFactor.toString()));
        }
      }
      final totalNeeded = alreadyInCart + needed;

      if (current < totalNeeded && !_allowNegativeStock) {
        throw Exception(
            'สต๊อกสินค้า "${product.name}" ไม่พอ (เหลือ: $current ชิ้น, ต้องการ: $totalNeeded ชิ้น)');
      }
    }

    // 2. Fetch Tiers
    List<ProductPriceTier> tiers = [];
    try {
      tiers = await _tierRepo.getTiersByProductId(product.id);
    } catch (e) {
      debugPrint('Error fetching tiers: $e');
    }
    final productWithTiers = product.copyWith(priceTiers: tiers);

    // 3. Determine Price
    final targetName =
        overrideUnit != null ? '${product.name} ($overrideUnit)' : product.name;
    final targetPrice = overridePrice ??
        _priceService.calculateUnitPrice(
            product: productWithTiers,
            quantity: quantity,
            customer: customer,
            customerTier: tier);

    // 4. Update or Add
    final index = _cart.indexWhere((item) =>
        item.productId == product.id && item.productName == targetName);

    if (index >= 0) {
      final existing = _cart[index];
      final newQty = existing.quantity + quantity;

      // Re-calculate price if tiered (based on new Qty)
      final productToUse =
          existing.product?.copyWith(priceTiers: tiers) ?? productWithTiers;
      final newPrice = overridePrice ??
          _priceService.calculateUnitPrice(
              product: productToUse,
              quantity: newQty,
              customer: customer,
              customerTier: tier);

      _cart[index] = existing.copyWith(
        quantity: newQty,
        price: newPrice,
        product: productToUse,
        // Total will be recalc by service logic implicitly? No, need to set total logic.
      );
      // Update line total
      _cart[index] = _priceService.recalculateItemTotal(_cart[index]);
    } else {
      final newItem = OrderItem(
        productId: product.id,
        productName: targetName,
        quantity: quantity,
        price: targetPrice,
        discount: Decimal.zero,
        total: Decimal.zero, // will calc next
        costPrice: product.costPriceDecimal, // ✅ Pass Cost Price
        conversionFactor: factor,
        product: productWithTiers,
      );
      _cart.add(_priceService.recalculateItemTotal(newItem));
    }

    notifyListeners();
  }

  Future<void> updateItemQuantity(
      int index, Decimal newQty, Customer? customer, MemberTier? tier) async {
    if (index < 0 || index >= _cart.length) return;
    // Removed auto-deletion on quantity zero to allow easier decimal typing (e.g. 0.5)
    // and prevent accidental removal. User should use explicit delete button.

    final existing = _cart[index];

    // 1. Stock Check
    if (existing.product != null && existing.product!.trackStock) {
      final current = Decimal.parse(existing.product!.stockQuantity.toString());
      final needed =
          newQty * Decimal.parse(existing.conversionFactor.toString());

      Decimal alreadyInCart = Decimal.zero;
      for (int i = 0; i < _cart.length; i++) {
        if (i != index && _cart[i].productId == existing.productId) {
          alreadyInCart += (_cart[i].quantity *
              Decimal.parse(_cart[i].conversionFactor.toString()));
        }
      }
      final totalNeeded = alreadyInCart + needed;

      if (current < totalNeeded && !_allowNegativeStock) {
        throw Exception(
            'สต๊อกสินค้า "${existing.productName}" ไม่พอ (เหลือ: $current ชิ้น, ต้องการ: $totalNeeded ชิ้น)');
      }
    }

    // 2. Recalc Price — ห้าม recalc ถ้าราคาถูก override โดย user
    Decimal newPrice = existing.price;
    if (!existing.isPriceOverridden && existing.product != null) {
      // ราคาปกติ (ไม่ถูกแก้ไข) → คำนวณจาก tier/customer
      newPrice = _priceService.calculateUnitPrice(
          product: existing.product!,
          quantity: newQty,
          customer: customer,
          customerTier: tier);
    }
    // ถ้า isPriceOverridden=true → ใช้ existing.price เดิมต่อไป (ไม่ recalc)

    // 3. Recalc Discount if per_piece mode
    final String mode = SettingsService().itemDiscountMode;
    Decimal newDiscount = existing.discount;
    if (mode == 'per_piece' && existing.quantity > Decimal.zero) {
      newDiscount = ((existing.discount * newQty) / existing.quantity)
          .toDecimal(scaleOnInfinitePrecision: 10);
    }

    _cart[index] = existing.copyWith(
        quantity: newQty, price: newPrice, discount: newDiscount);
    _cart[index] = _priceService.recalculateItemTotal(_cart[index]);
    notifyListeners();
  }

  void updateItemPrice(int index, Decimal newPrice) {
    if (index >= 0 && index < _cart.length) {
      final oldItem = _cart[index];
      // ตั้ง isPriceOverridden=true เพื่อหยุด recalc อัตโนมัติตอน qty เปลี่ยน
      _cart[index] = oldItem.copyWith(
        price: newPrice,
        isPriceOverridden: true,
      );
      _cart[index] = _priceService.recalculateItemTotal(_cart[index]);
      notifyListeners();
    }
  }

  void updateItemDiscount(int index, Decimal discountVal,
      {bool isPercent = false}) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    Decimal rawTotal = item.price * item.quantity;
    
    // Check global item discount mode
    final String mode = SettingsService().itemDiscountMode;
    
    Decimal actualDiscount = Decimal.zero;
    if (isPercent) {
      actualDiscount = ((rawTotal * discountVal) / Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 10);
    } else {
      if (mode == 'per_piece') {
        actualDiscount = discountVal * item.quantity;
      } else {
        actualDiscount = discountVal;
      }
    }

    // Clamp to rawTotal
    if (actualDiscount > rawTotal) actualDiscount = rawTotal;

    _cart[index] = item.copyWith(
      discount: actualDiscount,
      // Don't calculate total here, let recalculateItemTotal handle it
    );
    // Use service to ensure consistency
    _cart[index] = _priceService.recalculateItemTotal(_cart[index]);

    notifyListeners();
  }

  void updateItemComment(int index, String comment) {
    if (index >= 0 && index < _cart.length) {
      _cart[index] = _cart[index].copyWith(comment: comment);
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _cart.length) {
      _cart.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // Directly set cart (e.g. from Recall)
  void setCart(List<OrderItem> items) {
    _cart = List.from(items);
    notifyListeners();
  }

  // เรียกเมื่อ customer/tier เปลี่ยน — ข้าม item ที่ override ราคาไว้แล้ว
  void recalculateAllPrices(Customer? customer, MemberTier? tier) {
    for (int i = 0; i < _cart.length; i++) {
      final item = _cart[i];
      if (item.product == null) continue;
      // ห้าม recalc ถ้าราคาถูก override โดย user
      if (item.isPriceOverridden) continue;
      final newPrice = _priceService.calculateUnitPrice(
        product: item.product!,
        quantity: item.quantity,
        customer: customer,
        customerTier: tier,
      );
      _cart[i] = _priceService.recalculateItemTotal(
        item.copyWith(price: newPrice),
      );
    }
    notifyListeners();
  }
}
