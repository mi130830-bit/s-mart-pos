import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../customer_display_provider.dart';

/// Left panel of the Customer Display Screen.
/// Shows a welcome idle screen when the cart is empty,
/// or a live item list when items are present.
class ItemListSection extends StatelessWidget {
  final CustomerDisplayState state;
  final String? shopName;
  final double fontSize;

  const ItemListSection({
    super.key,
    required this.state,
    required this.shopName,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 100, color: Colors.blue.shade100),
            const SizedBox(height: 20),
            Text(
              shopName ?? 'ยินดีต้อนรับ',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Text('ขอบคุณที่ใช้บริการ',
                style: TextStyle(fontSize: 20, color: Colors.grey)),
          ],
        ),
      );
    }

    // Use real-time font size from state, fall back to local setting
    final double effectiveFontSize = fontSize;
    final double headerPadding = effectiveFontSize;
    final double itemVerticalPadding = effectiveFontSize * 0.4;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(headerPadding),
          color: Colors.blue,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'รายการสินค้า',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: effectiveFontSize,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'รวม',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: effectiveFontSize,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView.separated(
                key: ValueKey(state.items.length),
                controller: ScrollController(
                  initialScrollOffset: state.items.length * 1000.0,
                ),
                padding: EdgeInsets.all(headerPadding / 2),
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: itemVerticalPadding, horizontal: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: TextStyle(
                                    fontSize: effectiveFontSize,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${item['qty']} x ${NumberFormat('#,##0.00').format(item['price'])}',
                                style: TextStyle(
                                    fontSize: effectiveFontSize * 0.85,
                                    color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          NumberFormat('#,##0.00').format(item['total']),
                          style: TextStyle(
                              fontSize: effectiveFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
