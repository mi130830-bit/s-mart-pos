part of '../pos_state_manager.dart';

extension PosCartExtension on PosStateManager {
  Future<void> addProductToCart(Product product,
      {double quantity = 1.0,
      double? overridePrice,
      String? overrideUnit,
      double? overrideConversionFactor}) async {
    _hardwareService.setSuppressDisplay(false);
    Product freshProduct = product;
    if (product.id > 0 && product.trackStock) {
      try {
        final fetched = await _productRepo.getProductById(product.id);
        if (fetched != null) freshProduct = fetched;
      } catch (e) {
        debugPrint('⚠️ [PosState] Could not re-fetch stock for ${product.name}: $e');
      }
    }
    await _cartService.addProduct(
        product: freshProduct,
        quantity: Decimal.parse(quantity.toString()),
        overridePrice: overridePrice != null
            ? Decimal.parse(overridePrice.toString())
            : null,
        overrideUnit: overrideUnit,
        overrideConversionFactor: overrideConversionFactor,
        customer: _currentCustomer,
        tier: currentTier);
  }

  Future<void> removeItem(int index) async => _cartService.removeItem(index);

  Future<void> updateItemPrice(int index, Decimal newPrice) async =>
      _cartService.updateItemPrice(index, newPrice);

  Future<void> updateItemQuantity(int index, Decimal newQuantity) async =>
      await _cartService.updateItemQuantity(
          index, newQuantity, _currentCustomer, currentTier);

  void updateItemDiscount(int index, double discountVal,
      {bool isPercent = false}) {
    _cartService.updateItemDiscount(
        index, Decimal.parse(discountVal.toString()),
        isPercent: isPercent);
  }

  void updateItemComment(int index, String comment) =>
      _cartService.updateItemComment(index, comment);

  Future<void> clearCart({bool returnStock = false}) async {
    _cartService.clearCart();
    _currentCustomer = null;
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _promoDiscount = Decimal.zero;
    _pointsToRedeem = 0;
  }

  Future<ScanResult> handleBarcode(String barcode,
      {double quantity = 1.0}) async {
    if (barcode.isEmpty) {
      return ScanResult(status: ScanStatus.error, message: 'Barcode is empty');
    }
    final normalized = BarcodeUtils.fixThaiInput(barcode.trim());
    try {
      final matches = await _productRepo.getProductsPaginated(1, 10,
          searchTerm: normalized);
      Product? exactMatch;
      try {
        exactMatch = matches.firstWhere((p) => p.barcode == normalized);
      } catch (_) {}

      if (exactMatch == null) {
        final match = await _productRepo.findProductBarcode(normalized);
        if (match != null) {
          try {
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
      }

      if (exactMatch != null) {
        if (isWeighingProduct(exactMatch)) {
          return ScanResult(status: ScanStatus.requiresWeight, product: exactMatch);
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
        }
        return ScanResult(status: ScanStatus.multipleMatches, matches: matches);
      }
      return ScanResult(status: ScanStatus.notFound);
    } catch (e) {
      debugPrint('Scan Error: $e');
      return ScanResult(status: ScanStatus.error, message: e.toString());
    }
  }

  Future<List<Product>> searchProducts(String term) async =>
      await _productRepo.getProductsPaginated(1, 50, searchTerm: term);

  Future<int> createNewProduct(Product product) async =>
      await _productRepo.saveProduct(product);

  Future<void> addQuickSaleItem(
      {required String name, required double price, double quantity = 1.0}) async {
    final tempProduct = Product(
        id: -999,
        name: name,
        barcode: '',
        retailPrice: price,
        costPrice: 0,
        productType: 0,
        stockQuantity: 0,
        trackStock: false,
        points: 0);
    await addProductToCart(tempProduct, quantity: quantity);
  }

  bool isWeighingProduct(Product product) => false;
}
