import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class PaymentSummarySection extends StatelessWidget {
  final Decimal grandTotal;
  final Decimal totalPaid;
  final Decimal remaining;
  final Decimal change;
  final bool isFullyPaid;

  const PaymentSummarySection({
    super.key,
    required this.grandTotal,
    required this.totalPaid,
    required this.remaining,
    required this.change,
    required this.isFullyPaid,
  });

  Widget _buildInfoColumn(String label, Decimal val, Color color,
      {double fontSize = 28}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(
          '฿${NumberFormat('#,##0.00').format(val.toDouble())}',
          style: TextStyle(
              fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildDivider({double height = 40}) {
    return Container(width: 1, height: height, color: Colors.grey.shade300);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
          color: isFullyPaid ? Colors.green.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isFullyPaid ? Colors.green.shade200 : Colors.blue.shade200,
              width: 2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoColumn('ยอดรวมทั้งหมด', grandTotal, Colors.black87),
          _buildDivider(height: 50),
          _buildInfoColumn('รับเงินมาแล้ว', totalPaid, Colors.blue.shade800),
          _buildDivider(height: 50),
          if (!isFullyPaid)
            _buildInfoColumn('ยังค้างชำระ', remaining, Colors.red)
          else
            _buildInfoColumn('เงินทอน (Change)', change, Colors.green.shade800,
                fontSize: 36),
        ],
      ),
    );
  }
}
