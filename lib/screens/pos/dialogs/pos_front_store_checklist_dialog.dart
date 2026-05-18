import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/order_item.dart';
import '../../../services/printing/receipt_service.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog แสดงรายการสินค้าหน้าร้าน (Front Store) หลังชำระเงิน
class PosFrontStoreChecklistDialog {
  static Future<void> show(
    BuildContext context, {
    required List<OrderItem> items,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final List<bool> checked = List.filled(items.length, false);
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.store, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('รายการจัดของหน้าร้าน (Front Store List)'),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: isDark ? Colors.blue[900] : Colors.blue[50],
                      child: const Text(
                          'กรุณาจัดเตรียมสินค้าเหล่านี้ให้ลูกค้า (ไม่รวมของหลังร้าน)'),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          return CheckboxListTile(
                            value: checked[i],
                            onChanged: (val) =>
                                setState(() => checked[i] = val ?? false),
                            title: Text(item.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'จำนวน: ${NumberFormat('#,##0.##').format(item.quantity)} หน่วย'),
                            secondary: (item.product?.shelfLocation != null &&
                                    item.product!.shelfLocation!.isNotEmpty)
                                ? Chip(
                                    label: Text(
                                        'shelf: ${item.product!.shelfLocation}'),
                                    backgroundColor: isDark
                                        ? Colors.yellow[800]
                                        : Colors.yellow[100],
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CustomButton(
                  label: 'พิมพ์ใบจัดของ (Print)',
                  icon: Icons.print,
                  onPressed: () {
                    Navigator.pop(ctx);
                    ReceiptService().printPickingList(items);
                    AlertService.show(
                        context: context,
                        message: 'ส่งพิมพ์ใบจัดของเรียบร้อย',
                        type: 'success');
                  },
                ),
                CustomButton(
                  label: 'ปิด (Close)',
                  type: ButtonType.secondary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
