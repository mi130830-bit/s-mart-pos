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
import 'price_calculation_service.dart';

class CartService extends ChangeNotifier {
  final MySQLService _dbService;
  final ProductPriceTierRepository _tierRepo = ProductPriceTierRepository();
  final PriceCalculationService _priceService;

  List<OrderItem> _cart = [];
  List<OrderItem> get cart => List.unmodifiable(_cart);

  bool _allowNegativeStock = true;

  CartService(this._dbService, this._priceService);

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
      if (!_dbService.isConnected()) await _dbService.connect();
      final res = await _dbService.query(
          'SELECT stockQuantity, name FROM product WHERE id = :id',
          {'id': product.id});
      if (res.isNotEmpty) {
        final current = Decimal.parse(res.first['stockQuantity'].toString());
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
              'สินค้า "${res.first['name']}" หมด/ไม่พอ (เหลือ: $current, ต้องการ: $totalNeeded)');
        }
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
        conversionFactor: factor,
        product: productWithTiers,
      );
      _cart.add(_priceService.recalculateItemTotal(newItem));
    }

    notifyListeners();
  }

  void updateItemQuantity(
      int index, Decimal newQty, Customer? customer, MemberTier? tier) {
    if (index < 0 || index >= _cart.length) return;
    if (newQty <= Decimal.zero) {
      removeItem(index);
      return;
    }

    final existing = _cart[index];

    // Recalc Price
    Decimal newPrice = existing.price;
    // Only recalculate unit price if product linked, OTHERWISE keep existing price (manual override might be active)
    // BUT current logic suggests: if quantity changes, we re-check tiers/pricing.
    // To support manual override persistence, we might need a flag in OrderItem.
    // For now, let's assume we re-calc unless it was a manual override which we can't track easily without flag.
    // Let's stick to standard re-calc logic for now.
    if (existing.product != null) {
      newPrice = _priceService.calculateUnitPrice(
          product: existing.product!,
          quantity: newQty,
          customer: customer,
          customerTier: tier);
    }

    _cart[index] = existing.copyWith(quantity: newQty, price: newPrice);
    _cart[index] = _priceService.recalculateItemTotal(_cart[index]);
    notifyListeners();
  }

  void updateItemPrice(int index, Decimal newPrice) {
    if (index >= 0 && index < _cart.length) {
      final oldItem = _cart[index];
      // When price is manually updated, do we lock it?
      // For now just update it.
      _cart[index] = oldItem.copyWith(price: newPrice);
      _cart[index] = _priceService.recalculateItemTotal(_cart[index]);
      notifyListeners();
    }
  }

  void updateItemDiscount(int index, Decimal discountVal,
      {bool isPercent = false}) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    Decimal rawTotal = item.price * item.quantity;
    Decimal actualDiscount = isPercent
        ? ((rawTotal * discountVal) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 10)
        : discountVal;

    // Clamp to rawTotal
    if (actualDiscount > rawTotal) actualDiscount = rawTotal;

    _cart[index] = item.copyWith(
        discount: actualDiscount,
        total: rawTotal -
            actualDiscount // Update total directly here or use service? Service does (price*qty - discount).
        );
    // Use service to ensure consistency? Service `recalculateItemTotal` takes item with discount set and calcs total.
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
}
