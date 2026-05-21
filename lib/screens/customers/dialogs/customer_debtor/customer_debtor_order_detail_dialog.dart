import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/order_item.dart';
import '../../../../repositories/sales_repository.dart';

/// Dialog แสดงรายละเอียดบิล (Order Items + Returns)
Future<void> showOrderDetailDialog({
  required BuildContext context,
  required int orderId,
  required SalesRepository salesRepo,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(child: CircularProgressIndicator()),
  );

  final result = await salesRepo.getOrderWithItems(orderId);
  if (!context.mounted) return;
  Navigator.pop(context); // Close Loading

  if (result == null) return;

  final items = result['items'] as List<OrderItem>;
  final returns = (result['returns'] as List<OrderItem>?) ?? [];
  final order = result['order'];
  final dt = DateTime.parse(order['createdAt'].toString());
  final moneyFormat = NumberFormat('#,##0.00');
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'รายละเอียดบิล #$orderId\n${dateFormat.format(dt)}',
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...items.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.productName),
                        subtitle: Text(
                            '${item.quantity} x ${moneyFormat.format(item.price.toDouble())}'),
                        trailing: Text(
                          moneyFormat.format(item.total.toDouble()),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )),
                  if (returns.isNotEmpty) ...[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('รายการคืนสินค้า / ส่วนลด',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                    ...returns.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName,
                              style: const TextStyle(color: Colors.red)),
                          subtitle: Text(
                              '${item.quantity} x ${moneyFormat.format(item.price.toDouble())}',
                              style: const TextStyle(color: Colors.red)),
                          trailing: Text(
                            moneyFormat.format(item.total.toDouble()),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ยอดรวมสุทธิ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                '฿${moneyFormat.format(double.tryParse(order['grandTotal'].toString()) ?? 0)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
      ],
    ),
  );
}
