import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/screens/products/stock_in/models/stock_in_item.dart';
import 'package:pos_desktop/screens/products/stock_in/pages/widgets/stock_in_table_row.dart';

void main() {
  testWidgets('StockInTableRow accepts controllers and triggers onChanged callbacks', (WidgetTester tester) async {
    // 1. Create mock model data
    final product = Product(
      id: 1,
      barcode: '123456789',
      name: 'Test Product',
      productType: 0,
      costPrice: 10.0,
      retailPrice: 20.0,
      stockQuantity: 100.0,
      points: 0,
    );

    final item = StockInItem(
      product: product,
      quantity: 5.0,
      costPrice: 10.0,
    );

    final qtyCtrl = TextEditingController(text: "5");
    final costCtrl = TextEditingController(text: "10");

    String lastQtyChangedValue = '';
    String lastCostChangedValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StockInTableRow(
            item: item,
            index: 0,
            unitName: 'ชิ้น',
            poStatus: 'NEW',
            qtyCtrl: qtyCtrl,
            costCtrl: costCtrl,
            onEdit: () {},
            onCalculate: () {},
            onDelete: () {},
            onQtyChanged: (val) {
              lastQtyChangedValue = val;
            },
            onCostChanged: (val) {
              lastCostChangedValue = val;
            },
          ),
        ),
      ),
    );

    // Verify initial values
    expect(find.text('5'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    // Type a new quantity in the text field
    final qtyField = find.byType(TextFormField).first;
    await tester.tap(qtyField);
    await tester.pump();

    await tester.enterText(qtyField, '12');
    await tester.pump();

    // Verify callback was triggered immediately with new text
    expect(lastQtyChangedValue, '12');

    // Type a new cost in the text field
    final costField = find.byType(TextFormField).at(1);
    await tester.tap(costField);
    await tester.pump();

    await tester.enterText(costField, '15.5');
    await tester.pump();

    expect(lastCostChangedValue, '15.5');

    // Clean up
    qtyCtrl.dispose();
    costCtrl.dispose();
  });
}
