import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../repositories/stock_repository.dart';

class StockLedgerTable extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final StockRepository stockRepo;
  final Function(int id, String supplier) onDelete;

  const StockLedgerTable({
    super.key,
    required this.orders,
    required this.stockRepo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final po = orders[i];
        final date = DateTime.tryParse(po['updatedAt'].toString()) ??
            DateTime.now(); // Use updatedAt for received time
        final total = double.tryParse(po['totalAmount'].toString()) ?? 0;
        final itemCount = po['itemCount'] ?? 0;
        final supplier = po['supplierName'] ?? 'ไม่ระบุ Supplier';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.inventory_2, color: Colors.white),
            ),
            title: Text('PO #${po['id']} - $supplier',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'วันที่รับ: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}\nเอกสาร: ${po['documentNo']} | จำนวน: $itemCount รายการ',
                style: TextStyle(color: Colors.grey[700])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '฿${NumberFormat('#,##0.00').format(total)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onDelete(po['id'], supplier),
                ),
              ],
            ),
            onTap: () async {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('รายละเอียด PO #${po['id']}'),
                  content: SizedBox(
                    width: 400,
                    height: 300,
                    child: FutureBuilder(
                      future: stockRepo.getPurchaseOrderItems(po['id']),
                      builder: (ctx, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items =
                            snapshot.data as List<Map<String, dynamic>>;
                        if (items.isEmpty) {
                          return const Center(child: Text('ไม่มีรายการสินค้า'));
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (ctx, i) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            final cost =
                                double.tryParse(item['costPrice'].toString()) ??
                                    0;
                            final qty =
                                double.tryParse(item['quantity'].toString()) ??
                                    0;
                            return ListTile(
                              title: Text(item['productName']),
                              subtitle: Text(
                                  'ทุน: ${NumberFormat('#,##0.00').format(cost)}'),
                              trailing: Text(
                                '${NumberFormat('#,##0').format(qty)} ชิ้น',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ปิด'),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
