import sys
import re

with open('lib/services/sales/cart_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add Riverpod import
content = content.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';")

# Replace class definition
class_def = '''class CartState {
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
  }'''

content = re.sub(r'class CartService extends ChangeNotifier \{.*?void setAllowNegativeStock\(bool allow\) \{\n    _allowNegativeStock = allow;\n  \}', class_def, content, flags=re.DOTALL)

# Replace _cart references and notifyListeners
content = content.replace('_cart.isEmpty', 'state.items.isEmpty')
content = content.replace('_cart.map', 'state.items.map')
content = content.replace('_cart = decoded.map', 'state = state.copyWith(items: decoded.map')
content = content.replace('.toList();\n        onLoaded', '.toList());\n        onLoaded')
content = content.replace('onLoaded(_cart);', 'onLoaded(state.items);')
content = content.replace('_cart = [];', 'state = state.copyWith(items: []);')

content = content.replace('for (var item in _cart) {', 'for (var item in state.items) {')
content = content.replace('_allowNegativeStock', 'state.allowNegativeStock')

# For methods mutating _cart, we need to create a copy, modify it, and set it back.
methods_to_fix = ['addProduct', 'updateItemQuantity', 'updateItemPrice', 'updateItemDiscount', 'updateItemComment', 'removeItem', 'recalculateAllPrices']

for method in methods_to_fix:
    pattern = r'(Future<void>|void)\s+' + method + r'\s*\([^\{]+\{\n'
    replacement = r'\g<0>    final currentCart = List<OrderItem>.from(state.items);\n'
    content = re.sub(pattern, replacement, content)

content = content.replace('final index = _cart.indexWhere', 'final index = currentCart.indexWhere')
content = content.replace('for (int i = 0; i < _cart.length; i++) {', 'for (int i = 0; i < currentCart.length; i++) {')
content = content.replace('_cart[i]', 'currentCart[i]')
content = content.replace('_cart[index]', 'currentCart[index]')
content = content.replace('_cart.add', 'currentCart.add')
content = content.replace('_cart.length', 'currentCart.length')
content = content.replace('_cart.removeAt', 'currentCart.removeAt')

# Special case for clearCart and setCart
content = content.replace('void clearCart() {\n    _cart.clear();\n    notifyListeners();\n  }', 'void clearCart() {\n    state = state.copyWith(items: []);\n  }')
content = content.replace('void setCart(List<OrderItem> items) {\n    _cart = List.from(items);\n    notifyListeners();\n  }', 'void setCart(List<OrderItem> items) {\n    state = state.copyWith(items: List.from(items));\n  }')

# Replace remaining notifyListeners()
content = re.sub(r'notifyListeners\(\);\n  \}', r'state = state.copyWith(items: currentCart);\n  }', content)

with open('lib/services/sales/cart_service_new.dart', 'w', encoding='utf-8') as f:
    f.write(content)
