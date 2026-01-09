import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../repositories/sales_repository.dart';
import '../../models/order_item.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final Customer customer;
  const CustomerHistoryScreen({super.key, required this.customer});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final SalesRepository _salesRepo = SalesRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await _salesRepo.getOrdersByCustomer(widget.customer.id);
    if (mounted) {
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันแสดงรายละเอียดสินค้าในบิล (Popup)
  Future<void> _showOrderDetail(int orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _salesRepo.getOrderWithItems(orderId);
    if (!mounted) return;
    Navigator.pop(context); // ปิด Loading

    if (result == null) return;

    final items = result['items'] as List<OrderItem>;
    final order = result['order'];
    final dt = DateTime.parse(order['createdAt'].toString());
    final moneyFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายละเอียดบิล #$orderId\n${dateFormat.format(dt)}',
            textAlign: TextAlign.center),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                          '${item.quantity} x ${moneyFormat.format(item.price)}'),
                      trailing: Text(
                        // ✅ แก้ไข: เอา '${...}' ออก เพราะ moneyFormat คืนค่าเป็น String อยู่แล้ว
                        moneyFormat.format(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
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

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ประวัติการซื้อ', style: TextStyle(fontSize: 16)),
            Text(
              '${widget.customer.firstName} ${widget.customer.lastName ?? ""}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('ยังไม่มีประวัติการซื้อ',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _orders.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final order = _orders[i];
                    final dt = DateTime.parse(order['createdAt'].toString());
                    final status = order['status'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child:
                            const Icon(Icons.receipt_long, color: Colors.blue),
                      ),
                      title: Text('บิล #${order['id']}'),
                      subtitle: Text(
                          '${dateFormat.format(dt)} | ${order['paymentMethod']}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '฿${moneyFormat.format(double.parse(order['grandTotal'].toString()))}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16),
                          ),
                          Text(
                            status,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () =>
                          _showOrderDetail(int.parse(order['id'].toString())),
                    );
                  },
                ),
    );
  }
}
