import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ตารางสรุปยอดขายเชื่อ (ค้างรับ) แยกตามช่วงเวลา
class DashboardCreditTable extends StatelessWidget {
  final Map<String, dynamic> creditStatsToday;
  final Map<String, dynamic> creditStatsWeek;
  final Map<String, dynamic> creditStatsMonth;
  final Map<String, dynamic> creditStatsYear;

  const DashboardCreditTable({
    super.key,
    required this.creditStatsToday,
    required this.creditStatsWeek,
    required this.creditStatsMonth,
    required this.creditStatsYear,
  });

  @override
  Widget build(BuildContext context) {
    final formatMoney = NumberFormat('#,##0.00');
    final formatCount = NumberFormat('#,##0');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)],
      ),
      child: DataTable(
        headingRowColor:
            WidgetStateColor.resolveWith((states) => Colors.red.shade50),
        dataRowMinHeight: 60,
        dataRowMaxHeight: 60,
        columns: const [
          DataColumn(
              label: Text('ช่วงเวลา',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('ยอดคงค้าง (บาท)',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('จำนวนบิล',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: [
          _buildRow('วันนี้', creditStatsToday, formatMoney, formatCount),
          _buildRow('สัปดาห์นี้', creditStatsWeek, formatMoney, formatCount),
          _buildRow('เดือนนี้', creditStatsMonth, formatMoney, formatCount),
          _buildRow('ปีนี้', creditStatsYear, formatMoney, formatCount),
        ],
      ),
    );
  }

  DataRow _buildRow(
    String label,
    Map<String, dynamic> stats,
    NumberFormat fmtMoney,
    NumberFormat fmtCount,
  ) {
    final amount = double.tryParse(stats['amount'].toString()) ?? 0.0;
    final count = int.tryParse(stats['count'].toString()) ?? 0;

    return DataRow(cells: [
      DataCell(
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(fmtMoney.format(amount),
          style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(fmtCount.format(count),
            style: TextStyle(
                color: Colors.red.shade700, fontWeight: FontWeight.bold)),
      )),
    ]);
  }
}
