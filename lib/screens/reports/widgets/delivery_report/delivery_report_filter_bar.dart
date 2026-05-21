import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeliveryReportFilterBar extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String searchQuery;
  final int totalCount;
  final double totalAmount;
  final double totalFuelCost;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final Function(String) onSearchChanged;

  const DeliveryReportFilterBar({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.searchQuery,
    required this.totalCount,
    required this.totalAmount,
    required this.totalFuelCost,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final moneyFormat = NumberFormat('#,##0.00');

    return Container(
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 20),
          const SizedBox(width: 12),
          const Text('เริ่ม:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onPickStartDate,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(dateFormat.format(startDate),
                style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 16),
          const Text('ถึง:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onPickEndDate,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(dateFormat.format(endDate),
                style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 250,
            height: 38,
            child: TextField(
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: searchQuery,
                  selection: TextSelection.collapsed(offset: searchQuery.length),
                ),
              ),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อลูกค้า, คนขับ...',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              onChanged: onSearchChanged,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ทั้งหมด $totalCount งาน | ยอดขายรวม ฿${moneyFormat.format(totalAmount)}',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: colorScheme.primary),
              ),
              Text(
                'ต้นทุนน้ำมันรวม: ฿${moneyFormat.format(totalFuelCost)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                    fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
