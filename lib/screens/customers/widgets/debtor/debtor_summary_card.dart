import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DebtorSummaryCard extends StatelessWidget {
  final double totalDebt;
  final int debtorCount;
  final int billCount;
  final bool isSendingAlerts;
  final VoidCallback onSendBulkAlerts;

  const DebtorSummaryCard({
    super.key,
    required this.totalDebt,
    required this.debtorCount,
    required this.billCount,
    required this.isSendingAlerts,
    required this.onSendBulkAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ยอดลูกหนี้คงค้างรวม (Total Receivables)',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '฿${NumberFormat('#,##0.00').format(totalDebt)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$debtorCount รายลูกหนี้ ($billCount บิลคงค้าง)',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: isSendingAlerts ? null : onSendBulkAlerts,
            icon: isSendingAlerts
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.orange,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.notifications_active, color: Colors.orange),
            label: Text(isSendingAlerts ? 'กำลังส่ง...' : 'ทวงหนี้ทั้งหมด'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
