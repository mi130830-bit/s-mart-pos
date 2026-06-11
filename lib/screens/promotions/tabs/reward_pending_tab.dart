import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/reward_management_controller.dart';
import '../../../repositories/reward_repository.dart';

class RewardPendingTab extends ConsumerWidget {
  const RewardPendingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rewardManagementProvider);
    final controller = ref.read(rewardManagementProvider.notifier);

    final pending = state.redemptions.where((r) => r.isPending && !r.isCoupon).toList();
    if (pending.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text('ไม่มีรายการที่รอจัดส่ง 🎉', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('ทุกรายการจัดส่งเรียบร้อยแล้ว', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    
    return RefreshIndicator(
      onRefresh: controller.loadRedemptions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = pending[i];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.card_giftcard, color: Colors.amber.shade700),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.rewardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${r.customerName} ${r.phone != null ? '(${r.phone})' : ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(r.redeemedAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
                    child: Text('${r.pointsUsed} แต้ม', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _fulfillRedemption(context, controller, r),
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('ให้ของแล้ว', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fulfillRedemption(BuildContext context, RewardManagementController controller, RedemptionRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✅ ยืนยันการให้ของรางวัล'),
        content: Text('ยืนยันว่าได้มอบ "${record.rewardName}" ให้กับคุณ ${record.customerName} แล้วหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน ✅', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final ok = await controller.fulfillRedemption(record.id);
      if (ok && context.mounted) {
        SnackbarUtils.showLeft(context, '✅ บันทึกการให้ของรางวัลเรียบร้อย');
      }
    }
  }
}
