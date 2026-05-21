import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/reward_management_controller.dart';

class RewardHistoryTab extends ConsumerWidget {
  const RewardHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rewardManagementProvider);
    final controller = ref.read(rewardManagementProvider.notifier);

    if (state.redemptions.isEmpty) {
      return const Center(child: Text('ยังไม่มีประวัติการแลกรางวัล', style: TextStyle(color: Colors.grey)));
    }
    
    return RefreshIndicator(
      onRefresh: controller.loadRedemptions,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
          columns: const [
            DataColumn(label: Text('ลูกค้า', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ของรางวัล', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('แต้ม', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ประเภท', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: state.redemptions.map((r) {
            final statusWidget = r.isCoupon
                ? _statusChip(r.status == 'FULFILLED' ? 'ใช้แล้ว' : 'รอใช้', r.status == 'FULFILLED' ? Colors.grey : Colors.blue)
                : _statusChip(r.isFulfilled ? 'จัดส่งแล้ว' : 'รอจัดส่ง', r.isFulfilled ? Colors.green : Colors.orange);
            return DataRow(cells: [
              DataCell(Text('${r.customerName}\n${r.phone ?? ''}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(r.rewardName, style: const TextStyle(fontSize: 12))),
              DataCell(Text('${r.pointsUsed}', style: const TextStyle(fontSize: 12))),
              DataCell(r.isCoupon
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎟️ ', style: TextStyle(fontSize: 14)),
                      Text('ลด ฿${r.discountValue?.toStringAsFixed(0) ?? '-'}', style: const TextStyle(fontSize: 12)),
                    ])
                  : const Text('🎁 ของรางวัล', style: TextStyle(fontSize: 12))),
              DataCell(Text(DateFormat('dd/MM/yy HH:mm').format(r.redeemedAt), style: const TextStyle(fontSize: 12))),
              DataCell(statusWidget),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: color.withValues(alpha: 0.5))
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
