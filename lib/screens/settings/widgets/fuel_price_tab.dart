import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FuelPriceTab extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> prices;
  final Map<String, dynamic>? latestPrice;
  final VoidCallback onAddPrice;
  final void Function(Map<String, dynamic> row) onEditPrice;
  final void Function(Map<String, dynamic> row) onDeletePrice;

  const FuelPriceTab({
    super.key,
    required this.isLoading,
    required this.prices,
    required this.latestPrice,
    required this.onAddPrice,
    required this.onEditPrice,
    required this.onDeletePrice,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFormat = NumberFormat('#,##0.00');

    return Column(
      children: [
        // Header Banner
        Container(
          color: Colors.amber.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.local_gas_station, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ราคาน้ำมันดีเซล',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (latestPrice != null)
                      Text(
                        'ปัจจุบัน: ${moneyFormat.format(double.tryParse(latestPrice!['price_per_liter']?.toString() ?? '0') ?? 0)} บาท/ลิตร '
                        '(มีผลตั้งแต่ ${latestPrice!['effective_date']})',
                        style: const TextStyle(color: Colors.orange, fontSize: 13),
                      )
                    else
                      const Text('ยังไม่มีราคาน้ำมัน — กรุณาเพิ่มราคา',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAddPrice,
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มราคา'),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : prices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_gas_station, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('ยังไม่มีข้อมูลราคาน้ำมัน',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: onAddPrice,
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มราคาวันนี้'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(cs.primary.withValues(alpha: 0.1)),
                        columns: const [
                          DataColumn(label: Text('วันที่มีผล')),
                          DataColumn(label: Text('ราคา (บาท/ลิตร)'), numeric: true),
                          DataColumn(label: Text('หมายเหตุ')),
                          DataColumn(label: Text('จัดการ')),
                        ],
                        rows: prices.map((row) {
                          final isLatest = row['id'] == latestPrice?['id'];
                          final price =
                              double.tryParse(row['price_per_liter']?.toString() ?? '0') ?? 0.0;
                          return DataRow(
                            color: isLatest
                                ? WidgetStateProperty.all(Colors.orange.shade50)
                                : null,
                            cells: [
                              DataCell(Row(
                                children: [
                                  if (isLatest)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.star, color: Colors.orange, size: 14),
                                    ),
                                  Text(
                                    row['effective_date']?.toString() ?? '-',
                                    style: isLatest
                                        ? const TextStyle(fontWeight: FontWeight.bold)
                                        : null,
                                  ),
                                ],
                              )),
                              DataCell(Text(
                                moneyFormat.format(price),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLatest ? Colors.orange.shade800 : null,
                                ),
                              )),
                              DataCell(Text(row['note']?.toString() ?? '-')),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    tooltip: 'แก้ไข',
                                    onPressed: () => onEditPrice(row),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    tooltip: 'ลบ',
                                    onPressed: () => onDeletePrice(row),
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}
