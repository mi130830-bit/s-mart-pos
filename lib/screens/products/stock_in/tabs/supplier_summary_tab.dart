import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../repositories/stock_repository.dart';
import '../screens/supplier_order_history_screen.dart';

class SupplierSummaryTab extends StatefulWidget {
  const SupplierSummaryTab({super.key});

  @override
  State<SupplierSummaryTab> createState() => _SupplierSummaryTabState();
}

class _SupplierSummaryTabState extends State<SupplierSummaryTab> {
  final StockRepository _stockRepo = StockRepository();
  bool _isLoading = false;
  List<Map<String, dynamic>> _summaryList = [];
  DateTime? _selectedDate;

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
      if (_selectedDate != null) {
        startDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
        endDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
      }
      final received = await _stockRepo.getPurchaseOrders(status: 'RECEIVED', startDate: startDate, endDate: endDate, limit: 1000);
      final Map<int, Map<String, dynamic>> grouped = {};
      for (var order in received) {
        final supplierId = int.tryParse(order['supplierId']?.toString() ?? '0') ?? 0;
        final supplierName = order['supplierName']?.toString() ?? 'ไม่ระบุ';
        final totalAmount = double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
        if (!grouped.containsKey(supplierId)) {
          grouped[supplierId] = {'supplierId': supplierId, 'supplierName': supplierName, 'orderCount': 0, 'totalAmount': 0.0};
        }
        grouped[supplierId]!['orderCount'] = (grouped[supplierId]!['orderCount'] as int) + 1;
        grouped[supplierId]!['totalAmount'] = (grouped[supplierId]!['totalAmount'] as double) + totalAmount;
      }
      if (mounted) {
        setState(() {
          _summaryList = grouped.values.toList();
          _summaryList.sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final totalGrand = _summaryList.fold<double>(0, (sum, item) => sum + (item['totalAmount'] as double));

    return Column(
      children: [
        // 🔎 Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate == null ? 'ทุกวัน (All Time)' : 'วันที่: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'ล้างวันที่',
                  onPressed: () { setState(() => _selectedDate = null); _loadData(); },
                ),
              ],
            ],
          ),
        ),

        if (_summaryList.isEmpty) ...[
          const SizedBox(height: 50),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('ไม่พบข้อมูลประวัติการรับเข้า', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        ] else ...[
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('ผู้ขาย', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('จำนวนบิล', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('ยอดรวม (บาท)', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _summaryList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = _summaryList[i];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierOrderHistoryScreen(
                          supplierId: item['supplierId'],
                          supplierName: item['supplierName'],
                          dateFilter: _selectedDate,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: i % 2 == 0 ? Colors.white : Colors.teal.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 50, child: Text('${i + 1}', style: const TextStyle(color: Colors.grey))),
                        Expanded(flex: 3, child: Text(item['supplierName'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('${item['orderCount']} บิล', textAlign: TextAlign.center)),
                        Expanded(
                          flex: 2,
                          child: Text(
                            NumberFormat('#,##0.00').format(item['totalAmount']),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const SizedBox(width: 44, child: Icon(Icons.chevron_right, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              border: Border(top: BorderSide(color: Colors.teal.shade100, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('รวมยอดรายจ่ายทั้งหมด: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                Text('฿${NumberFormat('#,##0.00').format(totalGrand)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(width: 60),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
