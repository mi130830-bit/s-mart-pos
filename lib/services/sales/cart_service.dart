// ignore_for_file: unused_field
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class CartState {
  final List<OrderItem> items;
  final bool allowNegativeStock;

  CartState({
    this.items = const [],
    this.allowNegativeStock = true,
  });

  CartState copyWith({
    List<OrderItem>? items,
    bool? allowNegativeStock,
  }) {
    return CartState(
      items: items ?? this.items,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
    );
  }
}

final cartProvider = NotifierProvider.autoDispose<CartNotifier, CartState>(CartNotifier.new);

class CartNotifier extends AutoDisposeNotifier<CartState> {
  late MySQLService _dbService;
  late ProductPriceTierRepository _tierRepo;
  late PriceCalculationService _priceService;

  @override
  CartState build() {
    _dbService = MySQLService();
    _tierRepo = ProductPriceTierRepository();
    _priceService = PriceCalculationService();
    return CartState();
  }

  List<OrderItem> get cart => state.items;

  void setAllowNegativeStock(bool allow) {
    state = state.copyWith(allowNegativeStock: allow);
  }

  // --- Persistence ---
  Future<void> saveCartToPrefs(
      {int? customerId,
      double discountVal = 0,
      bool isPercent = false,
      String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = userId != null ? '${userId}_' : '';

    if (state.items.isEmpty && customerId == null) {
      await prefs.remove('${prefix}cart_items');
      await prefs.remove('${prefix}cart_customer_id');
      await prefs.remove('${prefix}cart_discount');
      await prefs.remove('${prefix}cart_is_percent_discount');
      return;
    }

    final String cartJson =
        jsonEncode(state.items.map((item) => item.toJson()).toList());
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
        final loadedItems = decoded.map((item) => OrderItem.fromJson(item)).toList();
        state = state.copyWith(items: loadedItems);
        onLoaded(state.items);
      } else {
        // Clear if not found (switched user with empty cart)
        state = state.copyWith(items: []);
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
    final currentCart = List<OrderItem>.from(state.items);

    // 1. Stock Check
    if (product.trackStock) {
      // ✅ ใช้สต็อกที่อัปเดตอิงกับ Online/Composite ที่ผูกมากับ object Product ได้เลย (แทนการไป query raw DB ซึ่งทำให้สินค้าประกอบได้ค่าเป็น 0)
      final current = Decimal.parse(product.stockQuantity.toString());
      final needed = quantity * Decimal.parse(factor.toString());

      Decimal alreadyInCart = Decimal.zero;
      for (var item in state.items) {
        if (item.productId == product.id) {
          alreadyInCart += (item.quantity *
              Decimal.parse(item.conversionFactor.toString()));
        }
      }
      final totalNeeded = alreadyInCart + needed;

      if (current < totalNeeded && !state.allowNegativeStock) {
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
    final index = currentCart.indexWhere((item) =>
        item.productId == product.id && item.productName == targetName);

    if (index >= 0) {
      final existing = currentCart[index];
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

      currentCart[index] = existing.copyWith(
        quantity: newQty,
        price: newPrice,
        product: productToUse,
        // Total will be recalc by service logic implicitly? No, need to set total logic.
      );
      // Update line total
      currentCart[index] = _priceService.recalculateItemTotal(currentCart[index]);
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
      currentCart.add(_priceService.recalculateItemTotal(newItem));
    }

    state = state.copyWith(items: currentCart);
  }

  Future<void> updateItemQuantity(
      int index, Decimal newQty, Customer? customer, MemberTier? tier) async {
    final currentCart = List<OrderItem>.from(state.items);
    if (index < 0 || index >= currentCart.length) return;
    // Removed auto-deletion on quantity zero to allow easier decimal typing (e.g. 0.5)
    // and prevent accidental removal. User should use explicit delete button.

    final existing = currentCart[index];

    // 1. Stock Check
    if (existing.product != null && existing.product!.trackStock) {
      final current = Decimal.parse(existing.product!.stockQuantity.toString());
      final needed =
          newQty * Decimal.parse(existing.conversionFactor.toString());

      Decimal alreadyInCart = Decimal.zero;
      for (int i = 0; i < currentCart.length; i++) {
        if (i != index && currentCart[i].productId == existing.productId) {
          alreadyInCart += (currentCart[i].quantity *
              Decimal.parse(currentCart[i].conversionFactor.toString()));
        }
      }
      final totalNeeded = alreadyInCart + needed;

      if (current < totalNeeded && !state.allowNegativeStock) {
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

    currentCart[index] = existing.copyWith(
        quantity: newQty, price: newPrice, discount: newDiscount);
    currentCart[index] = _priceService.recalculateItemTotal(currentCart[index]);
    state = state.copyWith(items: currentCart);
  }

  void updateItemPrice(int index, Decimal newPrice) {
    final currentCart = List<OrderItem>.from(state.items);
    if (index >= 0 && index < currentCart.length) {
      final oldItem = currentCart[index];
      // ตั้ง isPriceOverridden=true เพื่อหยุด recalc อัตโนมัติตอน qty เปลี่ยน
      currentCart[index] = oldItem.copyWith(
        price: newPrice,
        isPriceOverridden: true,
      );
      currentCart[index] = _priceService.recalculateItemTotal(currentCart[index]);
      state = state.copyWith(items: currentCart);
    }
  }

  void updateItemDiscount(int index, Decimal discountVal,
      {bool isPercent = false}) {
    final currentCart = List<OrderItem>.from(state.items);
    if (index < 0 || index >= currentCart.length) return;
    final item = currentCart[index];
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

    currentCart[index] = item.copyWith(
      discount: actualDiscount,
      // Don't calculate total here, let recalculateItemTotal handle it
    );
    // Use service to ensure consistency
    currentCart[index] = _priceService.recalculateItemTotal(currentCart[index]);

    state = state.copyWith(items: currentCart);
  }

  void updateItemComment(int index, String comment) {
    final currentCart = List<OrderItem>.from(state.items);
    if (index >= 0 && index < currentCart.length) {
      currentCart[index] = currentCart[index].copyWith(comment: comment);
      state = state.copyWith(items: currentCart);
    }
  }

  void removeItem(int index) {
    final currentCart = List<OrderItem>.from(state.items);
    if (index >= 0 && index < currentCart.length) {
      currentCart.removeAt(index);
      state = state.copyWith(items: currentCart);
    }
  }

  void clearCart() {
    state = state.copyWith(items: []);
  }

  // Directly set cart (e.g. from Recall)
  void setCart(List<OrderItem> items) {
    state = state.copyWith(items: List.from(items));
  }

  // เรียกเมื่อ customer/tier เปลี่ยน — ข้าม item ที่ override ราคาไว้แล้ว
  void recalculateAllPrices(Customer? customer, MemberTier? tier) {
    final currentCart = List<OrderItem>.from(state.items);
    for (int i = 0; i < currentCart.length; i++) {
      final item = currentCart[i];
      if (item.product == null) continue;
      // ห้าม recalc ถ้าราคาถูก override โดย user
      if (item.isPriceOverridden) continue;
      final newPrice = _priceService.calculateUnitPrice(
        product: item.product!,
        quantity: item.quantity,
        customer: customer,
        customerTier: tier,
      );
      currentCart[i] = _priceService.recalculateItemTotal(
        item.copyWith(price: newPrice),
      );
    }
    state = state.copyWith(items: currentCart);
  }
}
