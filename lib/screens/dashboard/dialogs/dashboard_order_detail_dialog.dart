import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/order_item.dart';
import '../../../repositories/sales_repository.dart';
import '../../../state/auth_provider.dart';
import '../../pos/pos_state_manager.dart'; // ✅ [NEW]
import '../../../state/navigation_provider.dart';

/// Dialog แสดงรายละเอียดบิลขาย และรายละเอียดการชำระหนี้
class DashboardOrderDetailDialog {
  /// แสดงรายละเอียดบิลขาย พร้อมต้นทุน/กำไร (ตาม Permission)
  static Future<void> show(
    BuildContext context, {
    required int orderId,
    required SalesRepository salesRepo,
  }) async {
    if (!context.mounted) return;

    final result = await salesRepo.getOrderWithItems(orderId);
    if (result == null || !context.mounted) return;

    final order = result['order'] as Map<String, dynamic>;
    final items = (result['items'] as List<OrderItem>?) ?? [];
    final returns = (result['returns'] as List<OrderItem>?) ?? [];
    final moneyFormat = NumberFormat('#,##0.00');

    double grandTotal = double.tryParse(order['grandTotal'].toString()) ?? 0.0;
    double totalCost = 0.0;
    for (var item in items) {
      totalCost += item.costPrice.toDouble() * item.quantity.toDouble();
    }
    for (var item in returns) {
      totalCost += item.costPrice.toDouble() * item.quantity.toDouble();
    }
    double profit = grandTotal - totalCost;

    if (!context.mounted) return;
    // Use ProviderScope to read authProvider inside a static method
    late AuthState auth;
    final container = ProviderScope.containerOf(context, listen: false);
    auth = container.read(authProvider);
    final bool canViewCost = auth.hasPermission('view_cost');
    final bool canViewProfit = auth.hasPermission('view_profit');
    // ✅ [NEW] ตรวจสิทธิ์แก้ไขบิล
    final bool canEditUnpaid = auth.hasPermission('edit_unpaid_order');
    final String orderStatus = order['status']?.toString().toUpperCase() ?? '';
    final bool isUnpaid = orderStatus == 'UNPAID';
    final bool isPaid = orderStatus == 'COMPLETED' || orderStatus == 'PAID';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายละเอียดบิล #$orderId'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('ลูกค้า: ${order['firstName'] ?? "ทั่วไป"}'),
                subtitle: Text('วันที่: ${order['createdAt']}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ยอดรวม: ฿${moneyFormat.format(grandTotal)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue),
                    ),
                    if (canViewCost || canViewProfit)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          [
                            if (canViewCost)
                              'ทุน: ฿${moneyFormat.format(totalCost)}',
                            if (canViewProfit)
                              'กำไร: ฿${moneyFormat.format(profit)}',
                          ].join(' | '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...items.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.quantity} x ${item.price}'),
                              if (item.discount.toDouble() > 0)
                                Text(
                                  'ส่วนลด: -${moneyFormat.format(item.discount.toDouble())}',
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Text(
                              '฿${moneyFormat.format(item.total.toDouble())}'),
                        )),
                    if (returns.isNotEmpty) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('รายการคืนสินค้า / ส่วนลด',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ),
                      ...returns.map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productName,
                                style: const TextStyle(color: Colors.red)),
                            subtitle: Text(
                                '${item.quantity} x ${item.price}',
                                style: const TextStyle(color: Colors.red)),
                            trailing: Text(
                                '฿${moneyFormat.format(item.total.toDouble())}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // ✅ [NEW] ปุ่มแก้ไขบิล — แสดงสำหรับบิล UNPAID/PAID และมีสิทธิ์
          if ((isUnpaid || isPaid) && canEditUnpaid)
            TextButton.icon(
              icon: const Icon(Icons.edit_note, color: Colors.orange),
              label: const Text('แก้ไขรายการ',
                  style: TextStyle(color: Colors.orange)),
              onPressed: () async {
                Navigator.pop(ctx);
                final posNotifier = container.read(posProvider.notifier);
                final success = await posNotifier.loadOrderForEditing(orderId);
                if (success) {
                  // ✅ Switch tab to POS screen (index 0)
                  container.read(mainNavigationProvider.notifier).state = 0;
                } else if (context.mounted) {
                  SnackbarUtils.showLeft(context, 'ไม่สามารถโหลดบิลนี้ได้', isError: true);
                }
              },
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
        ],
      ),
    );
  }

  /// แสดงรายละเอียดรายการชำระหนี้
  static Future<void> showDebtPayment(
    BuildContext context, {
    required Map<String, dynamic> row,
    required void Function(int orderId) onViewLinkedOrder,
  }) async {
    final int? refId = int.tryParse(row['refId'].toString());
    final String note = row['note']?.toString() ?? '';
    final String amount = NumberFormat('#,##0.00')
        .format(double.tryParse(row['amount'].toString()) ?? 0);
    final String dateStr = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.parse(row['createdAt'].toString()));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('รายละเอียดการชำระหนี้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('วันที่: $dateStr'),
            Text('ลูกค้า: ${row['customerName']}'),
            const Divider(),
            Text('ยอดชำระ: ฿$amount',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('หมายเหตุ: $note'),
            ],
            if (refId != null && refId > 0) ...[
              const SizedBox(height: 16),
              const Text('ชำระสำหรับบิล (Linked Bill):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onViewLinkedOrder(refId);
                },
                icon: const Icon(Icons.receipt),
                label: Text('ดูบิล #$refId'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
        ],
      ),
    );
  }
}
