import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/common/custom_buttons.dart';

class StockFilterPanel extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearFilter;

  const StockFilterPanel({
    super.key,
    required this.dateRange,
    required this.onPickDateRange,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 20, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateRange == null
                  ? 'แสดงทั้งหมด (ล่าสุด)'
                  : '${DateFormat('dd/MM/yyyy').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (dateRange != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onClearFilter,
              tooltip: 'ล้างตัวกรอง',
            ),
          CustomButton(
            onPressed: onPickDateRange,
            label: 'เลือกช่วงเวลา',
            type: ButtonType.primary,
          ),
        ],
      ),
    );
  }
}
