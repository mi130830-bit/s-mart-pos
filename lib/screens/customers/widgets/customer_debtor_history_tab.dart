import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tab แสดงประวัติการซื้อ
class CustomerDebtorHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> historyOrders;
  final NumberFormat moneyFormat;
  final DateFormat dateFormat;
  final void Function(int orderId) onShowOrderDetail;

  const CustomerDebtorHistoryTab({
    super.key,
    required this.historyOrders,
    required this.moneyFormat,
    required this.dateFormat,
    required this.onShowOrderDetail,
  });

  @override
  Widget build(BuildContext context) {
    if (historyOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ยังไม่มีประวัติการซื้อ',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: historyOrders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final order = historyOrders[i];
        final dt = DateTime.parse(order['createdAt'].toString());
        final status = order['status'];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: const Icon(Icons.receipt_long, color: Colors.blue),
          ),
          title: Text('บิล #${order['id']}'),
          subtitle: Text('${dateFormat.format(dt)} | ${order['paymentMethod']}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${moneyFormat.format(double.tryParse(order['grandTotal'].toString()) ?? 0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16),
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          onTap: () =>
              onShowOrderDetail(int.tryParse(order['id'].toString()) ?? 0),
        );
      },
    );
  }
}
