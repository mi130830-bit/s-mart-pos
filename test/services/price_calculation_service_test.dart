import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:pos_desktop/services/sales/price_calculation_service.dart';

import 'package:pos_desktop/models/order_item.dart';
import 'package:pos_desktop/models/product.dart';

void main() {
  late PriceCalculationService calcService;

  setUp(() {
    calcService = PriceCalculationService();
  });

  group('PriceCalculationService - calculateTotals', () {
    final productA = Product(
      id: 1,
      name: 'Item A',
      retailPrice: 100,
      costPrice: 80,
      productType: 1,
      trackStock: true,
      stockQuantity: 10,
      points: 0,
      barcode: '111',
    );

    // Helper to create basic items
    OrderItem createItem(double price, double qty) {
      return OrderItem(
          productId: 1,
          productName: 'Item',
          price: Decimal.parse(price.toString()),
          quantity: Decimal.parse(qty.toString()),
          total: Decimal.parse((price * qty).toString()), // Simple init
          discount: Decimal.zero,
          product: productA);
    }

    test('Basic Total - No Discount, No VAT', () {
      final cart = [
        createItem(100.0, 2.0), // 200
        createItem(50.0, 1.0), // 50
      ];
      // Total 250

      final result = calcService.calculateTotals(
          cart: cart,
          billDiscountVal: 0,
          isPercentDiscount: false,
          promoDiscountVal: 0,
          vatType: VatType.none);

      expect(result.grandTotal.toDouble(), 250.0);
      expect(result.vatAmount.toDouble(), 0.0);
    });

    test('Bill Discount - Amount', () {
      final cart = [createItem(100.0, 3.0)]; // 300

      final result = calcService.calculateTotals(
          cart: cart,
          billDiscountVal: 50.0,
          isPercentDiscount: false,
          promoDiscountVal: 0,
          vatType: VatType.none);

      expect(result.billDiscountAmount.toDouble(), 50.0);
      expect(result.grandTotal.toDouble(), 250.0);
    });

    test('Bill Discount - Percent', () {
      final cart = [createItem(100.0, 2.0)]; // 200

      final result = calcService.calculateTotals(
          cart: cart,
          billDiscountVal: 10.0, // 10%
          isPercentDiscount: true,
          promoDiscountVal: 0,
          vatType: VatType.none);

      // 10% of 200 = 20
      expect(result.billDiscountAmount.toDouble(), 20.0);
      expect(result.grandTotal.toDouble(), 180.0);
    });

    test('VAT Excluded (7%)', () {
      final cart = [createItem(100.0, 1.0)]; // 100

      final result = calcService.calculateTotals(
          cart: cart,
          billDiscountVal: 0,
          isPercentDiscount: false,
          promoDiscountVal: 0,
          vatType: VatType.excluded);

      // Price = 100
      // Vat = 100 * 0.07 = 7
      // Grand = 107
      expect(result.vatAmount.toDouble(), 7.0);
      expect(result.grandTotal.toDouble(), 107.0);
    });

    test('VAT Included (7%)', () {
      final cart = [createItem(107.0, 1.0)]; // 107 (Included VAT)

      final result = calcService.calculateTotals(
          cart: cart,
          billDiscountVal: 0,
          isPercentDiscount: false,
          promoDiscountVal: 0,
          vatType: VatType.included);

      // Grand = 107
      // Net = 107 / 1.07 = 100
      // Vat = 7
      expect(result.grandTotal.toDouble(), 107.0);
      expect(
          result.vatAmount.toDouble(),
          closeTo(
              7.0, 0.01)); // Decimal parsing might have tiny precision diffs
      expect(result.netTotal.toDouble(), closeTo(100.0, 0.01));
    });

    test('Complex: Discount then VAT', () {
      // 2 Items @ 100 = 200
      // Discount 20 baht -> 180
      // VAT Excluded -> 180 * 0.07 = 12.6
      // Grand = 192.6
      final cart = [createItem(100.0, 2.0)];

      final result = calcService.calculateTotals(
          cart: cart,
          billDiscountVal: 20.0,
          isPercentDiscount: false,
          promoDiscountVal: 0,
          vatType: VatType.excluded);

      expect(result.subtotalAfterBillDiscount.toDouble(), 180.0);
      expect(result.vatAmount.toDouble(), closeTo(12.6, 0.01));
      expect(result.grandTotal.toDouble(), closeTo(192.6, 0.01));
    });
  });

  group('PriceCalculationService - Edge Cases', () {
    final productA = Product(
      id: 1,
      name: 'Item A',
      retailPrice: 100,
      costPrice: 80,
      productType: 1,
      trackStock: true,
      stockQuantity: 10,
      points: 0,
      barcode: '111',
    );

    OrderItem createItem(double price, double qty) {
      return OrderItem(
        productId: 1,
        productName: 'Item',
        price: Decimal.parse(price.toString()),
        quantity: Decimal.parse(qty.toString()),
        total: Decimal.parse((price * qty).toString()),
        discount: Decimal.zero,
        product: productA,
      );
    }

    test('Promo Discount ลดได้ถูกต้อง', () {
      // Cart 200, promo 50 → grand = 150
      final cart = [createItem(100.0, 2.0)];

      final result = calcService.calculateTotals(
        cart: cart,
        billDiscountVal: 0,
        isPercentDiscount: false,
        promoDiscountVal: 50.0,
        vatType: VatType.none,
      );

      expect(result.promoDiscountAmount.toDouble(), 50.0);
      expect(result.grandTotal.toDouble(), 150.0);
    });

    test('Bill Discount + Promo Discount ลดรวมกัน', () {
      // Cart 300, billDiscount 50 → subtotal 250, promo 30 → grand 220
      final cart = [createItem(100.0, 3.0)];

      final result = calcService.calculateTotals(
        cart: cart,
        billDiscountVal: 50.0,
        isPercentDiscount: false,
        promoDiscountVal: 30.0,
        vatType: VatType.none,
      );

      expect(result.billDiscountAmount.toDouble(), 50.0);
      expect(result.promoDiscountAmount.toDouble(), 30.0);
      expect(result.grandTotal.toDouble(), 220.0);
    });

    test('Cart ว่าง (0 items) → grand = 0, vat = 0', () {
      final result = calcService.calculateTotals(
        cart: [],
        billDiscountVal: 0,
        isPercentDiscount: false,
        promoDiscountVal: 0,
        vatType: VatType.excluded,
      );

      expect(result.grandTotal.toDouble(), 0.0);
      expect(result.vatAmount.toDouble(), 0.0);
    });

    test('Discount เกินราคาสินค้า → Grand Total ไม่ติดลบ (Clamp)', () {
      // Cart 100, discount 500 → grand ต้องไม่เป็น -400
      final cart = [createItem(100.0, 1.0)];

      final result = calcService.calculateTotals(
        cart: cart,
        billDiscountVal: 500.0,
        isPercentDiscount: false,
        promoDiscountVal: 0,
        vatType: VatType.none,
      );

      expect(result.grandTotal.toDouble(), greaterThanOrEqualTo(0.0),
          reason: 'Grand ต้องไม่ติดลบ แม้ discount เกินราคา');
    });

    test('Rounding Mode "up" → Grand Total ถูก ceil', () {
      // Cart 1 item @ 100, VAT Excluded = 100 * 1.07 = 107.0 (ไม่มีเศษ)
      // ใช้ราคาที่มีเศษทศนิยม 99.5 → VAT = 99.5 * 1.07 = 106.465 → ceil → 107
      final cart = [createItem(99.5, 1.0)];

      final result = calcService.calculateTotals(
        cart: cart,
        billDiscountVal: 0,
        isPercentDiscount: false,
        promoDiscountVal: 0,
        vatType: VatType.excluded,
        roundingMode: 'up',
      );

      // 99.5 * 1.07 = 106.465 → ceil → 107
      expect(result.grandTotal.toDouble(), 107.0,
          reason: 'roundingMode=up ต้อง ceil grand total');
    });
  });
}
