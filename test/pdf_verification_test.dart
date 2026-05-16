import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/order_item.dart';
import 'package:pos_desktop/services/printing/delivery_note_pdf.dart';
import 'package:pos_desktop/services/pdf/tax_invoice_pdf.dart';
import 'package:pos_desktop/services/pdf/thermal_receipt_pdf.dart';
import 'package:pos_desktop/models/shop_info.dart';
import 'package:decimal/decimal.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({}); // Mock SharedPreferences

  final shopInfo = ShopInfo(
    name: 'Test Shop Full Name',
    address: 'Test Shop Address Full',
    taxId: '1234567890123',
    footer: 'Thank You',
    shortName: 'Shop Short',
    shortAddress: 'Addr Short',
    phone: '0123456789',
    promptPayId: '000-000-0000',
  );

  final customer = Customer(
      id: 1,
      firstName: 'Test',
      lastName: 'Customer',
      address: 'Test Address',
      phone: '0999999999',
      currentPoints: 0,
      memberCode: 'M001');

  final items = List.generate(
      30,
      (index) => OrderItem(
          productId: index + 1,
          productName: 'Item ${index + 1}',
          price: Decimal.fromInt(100),
          quantity: Decimal.fromInt(1),
          total: Decimal.fromInt(100)));

  group('PDF Generation Verification', () {
    test('Tax Invoice (A4) generation', () async {
      final bytes = await TaxInvoicePdf.generate(
          orderId: 1,
          items: items,
          total: 3000,
          grandTotal: 3000,
          vatRate: 7,
          customer: customer,
          pageFormat: PdfPageFormat.a4,
          shopInfo: shopInfo);
      expect(bytes, isNotEmpty);
      await File('test_tax_invoice_a4.pdf').writeAsBytes(bytes);
    });

    test('Tax Invoice (A5) generation', () async {
      // Custom A5 size similar to what we use
      final bytes = await TaxInvoicePdf.generate(
          orderId: 1,
          items: items,
          total: 3000,
          grandTotal: 3000,
          vatRate: 7,
          customer: customer,
          pageFormat: PdfPageFormat.a5,
          shopInfo: shopInfo);
      expect(bytes, isNotEmpty);
      await File('test_tax_invoice_a5.pdf').writeAsBytes(bytes);
    });

    test('Delivery Note (A4) generation', () async {
      final bytes = await DeliveryNotePdf.generate(
          orderId: 1,
          items: items,
          customer: customer,
          discount: 0,
          pageFormat: PdfPageFormat.a4,
          shopInfo: shopInfo);
      expect(bytes, isNotEmpty);
      await File('test_delivery_note_a4.pdf').writeAsBytes(bytes);
    });

    test('Delivery Note (A5) generation', () async {
      final bytes = await DeliveryNotePdf.generate(
          orderId: 1,
          items: items,
          customer: customer,
          discount: 0,
          pageFormat: PdfPageFormat.a5,
          shopInfo: shopInfo);
      expect(bytes, isNotEmpty);
      await File('test_delivery_note_a5.pdf').writeAsBytes(bytes);
    });

    test('Thermal Receipt (80mm) generation', () async {
      final bytes = await ThermalReceiptPdf.generate(
          orderId: 1,
          items: items.sublist(0, 5),
          total: 500,
          discount: 0,
          grandTotal: 500,
          received: 500,
          change: 0,
          customer: customer,
          pageFormat: PdfPageFormat.roll80,
          shopInfo: shopInfo);
      expect(bytes, isNotEmpty);
      await File('test_thermal_receipt_80mm.pdf').writeAsBytes(bytes);
    });
  });
}
