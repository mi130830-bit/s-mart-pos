import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/screens/products/stock_in/models/stock_in_item.dart';
import 'package:pos_desktop/screens/products/stock_in/pages/widgets/stock_in_table_row.dart';

void main() {
  testWidgets('StockInTableRow keeps local input state and notifies parent only on focus loss', (WidgetTester tester) async {
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

    int totalChangedCount = 0;

    // 2. Build the StockInTableRow widget inside a MaterialApp and scaffold/focus environment
    final focusNode2 = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // Extra focus target so we can shift focus away
              TextField(
                focusNode: focusNode2,
                key: const Key('dummy_focus_target'),
              ),
              StockInTableRow(
                item: item,
                index: 0,
                unitName: 'ชิ้น',
                poStatus: 'NEW',
                onEdit: () {},
                onCalculate: () {},
                onDelete: () {},
                onTotalChanged: () {
                  totalChangedCount++;
                },
              ),
            ],
          ),
        ),
      ),
    );

    // 3. Verify initial text controller values
    expect(find.text('5'), findsOneWidget); // initial quantity
    expect(find.text('10'), findsOneWidget); // initial costPrice

    // 4. Type a new quantity in the text field
    // Find the quantity field (first CustomTextField/TextFormField)
    final qtyField = find.byType(TextFormField).first;
    await tester.tap(qtyField);
    await tester.pump();

    // Enter a new value
    await tester.enterText(qtyField, '12');
    await tester.pump();

    // The text should update immediately in the local field without triggering onTotalChanged yet
    expect(find.text('12'), findsOneWidget);
    expect(totalChangedCount, 0); // Not called yet because focus is still on the field

    // 5. Shift focus away to trigger the onTotalChanged callback
    focusNode2.requestFocus();
    await tester.pump();

    // Verify callback was triggered when the quantity field lost focus
    expect(totalChangedCount, 1);
  });
}
