// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

// Services
import 'package:pos_desktop/services/sales/cart_service.dart';
import 'package:pos_desktop/services/sales/price_calculation_service.dart';
import 'package:pos_desktop/services/mysql_service.dart';
import 'package:pos_desktop/repositories/product_price_tier_repository.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_price_tier.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

// -------------------------------------------------------------
// Manual Mocks
// -------------------------------------------------------------

class MockMySQLService implements MySQLService {
  @override
  bool isConnected() => true;

  @override
  Future<void> connect() async {}

  @override
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    // Return dummy for now or throw if not expected
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProductPriceTierRepository implements ProductPriceTierRepository {
  @override
  Future<List<ProductPriceTier>> getTiersByProductId(int productId) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CartService cartService;
  late PriceCalculationService priceCalcService;
  late MockMySQLService mockDb;
  late MockProductPriceTierRepository mockTierRepo;

  setUp(() {
    mockDb = MockMySQLService();
    priceCalcService = PriceCalculationService();
    mockTierRepo = MockProductPriceTierRepository();
    // Inject mocks
    cartService = CartService(mockDb, priceCalcService, tierRepo: mockTierRepo);
  });

  group('Cart Logic Tests', () {
    test('Add Product increases cart count', () async {
      final p = Product(
        id: 1,
        name: 'Test Product',
        barcode: '123',
        retailPrice: 100.0,
        costPrice: 80.0,
        productType: 0,
        stockQuantity: 10,
        trackStock: true,
        points: 0,
      );

      await cartService.addProduct(product: p, quantity: Decimal.parse('1'));

      expect(cartService.cart.length, 1);
      expect(cartService.cart.first.productName, 'Test Product');
      expect(cartService.cart.first.quantity, 1.0);
      expect(cartService.cart.first.total.toDouble(), 100.0);
    });

    test('Add same product merges item', () async {
      final p = Product(
        id: 1,
        name: 'Test Product',
        barcode: '123',
        retailPrice: 100.0,
        costPrice: 80.0,
        productType: 0,
        stockQuantity: 10,
        trackStock: true,
        points: 0,
      );

      await cartService.addProduct(product: p, quantity: Decimal.parse('1'));
      await cartService.addProduct(product: p, quantity: Decimal.parse('2'));

      expect(cartService.cart.length, 1);
      expect(cartService.cart.first.quantity, 3.0);
      expect(cartService.cart.first.total.toDouble(), 300.0);
    });

    test('Update Quantity recalculates total', () async {
      final p = Product(
        id: 1,
        name: 'Test Product',
        barcode: '123',
        retailPrice: 100.0,
        costPrice: 80.0,
        productType: 0,
        stockQuantity: 10,
        trackStock: true,
        points: 0,
      );

      await cartService.addProduct(product: p, quantity: Decimal.parse('1'));
      // Update to 5 (Synchronous call)
      cartService.updateItemQuantity(0, Decimal.parse('5'), null, null);

      expect(cartService.cart.first.quantity, 5.0);
      expect(cartService.cart.first.total.toDouble(), 500.0);
    });

    test('Remove item decrements list', () async {
      final p = Product(
        id: 1,
        name: 'Test Product',
        barcode: '123',
        retailPrice: 100.0,
        costPrice: 80.0,
        productType: 0,
        stockQuantity: 10,
        trackStock: true,
        points: 0,
      );

      await cartService.addProduct(product: p, quantity: Decimal.parse('1'));
      cartService.removeItem(0);

      expect(cartService.cart.isEmpty, true);
    });

    test('Clear Cart removes all', () async {
      final p1 = Product(
          id: 1,
          name: 'P1',
          barcode: '1',
          retailPrice: 10,
          costPrice: 5,
          productType: 0,
          stockQuantity: 10,
          trackStock: false,
          points: 0);
      final p2 = Product(
          id: 2,
          name: 'P2',
          barcode: '2',
          retailPrice: 20,
          costPrice: 10,
          productType: 0,
          stockQuantity: 10,
          trackStock: false,
          points: 0);

      await cartService.addProduct(product: p1, quantity: Decimal.parse('1'));
      await cartService.addProduct(product: p2, quantity: Decimal.parse('1'));

      expect(cartService.cart.length, 2);

      cartService.clearCart();
      expect(cartService.cart.isEmpty, true);
    });
  });
}
