import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_item.dart'; // ⚠️ เช็ค path model ให้ถูกต้อง

class PosCartList extends StatelessWidget {
  final List<OrderItem> items;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final Function(int index, double newQty) onUpdateQuantity; // ✅ Added callback

  const PosCartList({
    super.key,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateQuantity, // ✅ Added
  });

  @override
  Widget build(BuildContext context) {
    const double colSequence = 35;
    const int flexItem = 5;
    const int flexPrice = 2;
    const int flexTotal = 2;
    const double colAction = 40;

    return Column(
      children: [
        // ... (Header unchanged) ...
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: const Row(children: [
            SizedBox(
                width: colSequence,
                child: Text('#',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: flexItem,
                child: Text(' รายการสินค้า',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: flexPrice,
                child: Text('ราคา',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: flexTotal,
                child: Text('รวม',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: colAction)
          ]),
        ),

        // List Items
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('ตะกร้าว่างเปล่า',
                      style: TextStyle(color: Colors.grey, fontSize: 18)))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return InkWell(
                      onTap: () => onEdit(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Sequence
                            SizedBox(
                              width: colSequence,
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey),
                              ),
                            ),
                            // 2. Item Name & Details
                            Expanded(
                              flex: flexItem,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ Name + Comment Inline
                                  Text.rich(
                                    TextSpan(
                                      text: item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87),
                                      children: [
                                        if (item.comment.isNotEmpty)
                                          TextSpan(
                                            text: ' (${item.comment})',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal,
                                                color: Colors.blueAccent,
                                                fontSize: 14),
                                          ),
                                      ],
                                    ),
                                    softWrap: true,
                                  ),
                                  const SizedBox(height: 4),
                                  // ✅ Quantity Control Row
                                  Row(
                                    children: [
                                      // Minus Button
                                      InkWell(
                                        onTap: () => onUpdateQuantity(
                                            i, item.quantity.toDouble() - 1),
                                        borderRadius: BorderRadius.circular(15),
                                        child: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                            color: Colors.red),
                                      ),
                                      const SizedBox(width: 8),
                                      // Quantity Text
                                      Text(
                                        NumberFormat('#,##0.##')
                                            .format(item.quantity.toDouble()),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      // Plus Button
                                      InkWell(
                                        onTap: () => onUpdateQuantity(
                                            i, item.quantity.toDouble() + 1),
                                        borderRadius: BorderRadius.circular(15),
                                        child: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20,
                                            color: Colors.green),
                                      ),
                                      const SizedBox(width: 8),
                                      // Price
                                      Text(
                                        'x ${NumberFormat('#,##0.00').format(item.price.toDouble())}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // 3. Price (Unit Price or... Total Line Price?)
                            // Header says "Price", usually Unit Price, but space is limited.
                            // Let's keep logic from before: It showed total in trailing.
                            // Header "Price" matches "Price" column?
                            // Previous code showed "Qty x Price" in subtitle and Total in trailing.
                            // Let's show Unit Price here or maybe keep it simple?
                            // User asked to "reduce size of left column" (maybe meaning list width).
                            // Let's stick to showing relevant financial info.
                            // Col 3: Unit Price
                            Expanded(
                              flex: flexPrice,
                              child: Text(
                                NumberFormat('#,##0.00')
                                    .format(item.price.toDouble()),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            // 4. Total Line
                            Expanded(
                              flex: flexTotal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat('#,##0.00')
                                        .format(item.total.toDouble()),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  if (item.discount.toDouble() > 0)
                                    Text(
                                      '-${NumberFormat('#,##0.##').format(item.discount.toDouble())}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.red),
                                    ),
                                ],
                              ),
                            ),
                            // 5. Delete Action
                            SizedBox(
                              width: colAction,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    size: 18, color: Colors.red),
                                onPressed: () => onDelete(i),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
