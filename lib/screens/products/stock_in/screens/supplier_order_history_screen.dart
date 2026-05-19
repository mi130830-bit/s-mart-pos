import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../repositories/stock_repository.dart';
import '../pages/stock_in_create_page.dart';

class SupplierOrderHistoryScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  final DateTime? dateFilter;

  const SupplierOrderHistoryScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
    this.dateFilter,
  });

  @override
  State<SupplierOrderHistoryScreen> createState() => _SupplierOrderHistoryScreenState();
}

class _SupplierOrderHistoryScreenState extends State<SupplierOrderHistoryScreen> {
  final StockRepository _stockRepo = StockRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      DateTime? startDate;
      DateTime? endDate;
      if (widget.dateFilter != null) {
        startDate = DateTime(widget.dateFilter!.year, widget.dateFilter!.month, widget.dateFilter!.day, 0, 0, 0);
        endDate = DateTime(widget.dateFilter!.year, widget.dateFilter!.month, widget.dateFilter!.day, 23, 59, 59);
      }
      final received = await _stockRepo.getPurchaseOrders(
        status: 'RECEIVED',
        startDate: startDate,
        endDate: endDate,
        supplierId: widget.supplierId,
      );
      if (mounted) {
        setState(() {
          _orders = received;
          _orders.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalSum = _orders.fold<double>(0, (sum, order) => sum + (double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text('สรุปประวัติผู้ขาย: ${widget.supplierName}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.dateFilter != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade50,
                    child: Text(
                      'ข้อมูลประจำวันที่: ${DateFormat('dd/MM/yyyy').format(widget.dateFilter!)}',
                      style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Row(
                    children: [
                      SizedBox(width: 50, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('เลขที่เอกสาร', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('รายการ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('ยอดรวม', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(child: Text('ไม่พบข้อมูล'))
                      : ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final order = _orders[i];
                            final dt = DateTime.parse(order['createdAt'].toString());
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(title: Text('รายละเอียดใบรับเข้า #${order['documentNo'] ?? order['id']}')),
                                      body: StockInCreatePage(existingPoId: int.tryParse(order['id'].toString())),
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    SizedBox(width: 50, child: Text('${i + 1}', style: const TextStyle(color: Colors.grey))),
                                    Expanded(flex: 2, child: Text(DateFormat('dd/MM/yyyy HH:mm').format(dt))),
                                    Expanded(flex: 2, child: Text(order['documentNo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 1, child: Text('${order['itemCount']}', textAlign: TextAlign.center)),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        NumberFormat('#,##0.00').format(double.tryParse(order['totalAmount'].toString()) ?? 0),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('ยอดรวมผู้ขายรายนี้: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        '฿${NumberFormat('#,##0.00').format(totalSum)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
