import 'package:flutter/foundation.dart'; // ✅ Import สำหรับ debugPrint
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/order_item.dart';
import 'package:pos_desktop/services/pdf/delivery_note_pdf.dart';
import 'package:pos_desktop/models/shop_info.dart';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final customer = Customer(
      id: 1,
      firstName: 'Test',
      lastName: 'Customer',
      address: 'Test Address',
      phone: '0900000000',
      currentPoints: 0,
      memberCode: 'M001');

  test('Reproduce NaN Error with Huge Header', () async {
    final longString = 'Long Text ' * 100;
    final shopInfoHuge = ShopInfo(
      name: 'Test Shop $longString',
      address: 'Test Address $longString',
      taxId: '123',
      footer: 'Thanks',
      shortName: 'Shop',
      shortAddress: 'Addr',
      phone: '0800000000',
      promptPayId: '000',
    );

    final items = List.generate(
        8,
        (index) => OrderItem(
            productId: index + 1,
            productName: 'Item $index',
            price: Decimal.fromInt(100),
            quantity: Decimal.fromInt(1),
            total: Decimal.fromInt(100)));

    try {
      await DeliveryNotePdf.generate(
          orderId: 1,
          items: items,
          customer: customer,
          discount: 0,
          pageFormat: PdfPageFormat.a4,
          shopInfo: shopInfoHuge);

      debugPrint('Did not crash with huge header.'); // ✅ แก้เป็น debugPrint
    } catch (e) {
      debugPrint(
          'Caught expected error with huge header: $e'); // ✅ แก้เป็น debugPrint
      expect(e.toString(), contains('NaN'));
    }
  });
}
