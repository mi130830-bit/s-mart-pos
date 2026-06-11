import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/promotion.dart';
import 'controllers/promotion_list_controller.dart';
import 'promotion_edit_screen.dart';

class PromotionListScreen extends ConsumerWidget {
  const PromotionListScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promotionListProvider);
    final controller = ref.read(promotionListProvider.notifier);

    // Refresh after returning from edit screen if needed, though ConsumerWidget will rebuild when state changes.
    // However, the edit screen saves to DB, so we might need a way to refresh. 
    // We'll wrap the push with a then() to trigger loadData().
    void showDialogAndRefresh([Promotion? promo]) async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => PromotionEditScreen(promotion: promo)),
      );
      if (result == true) {
        controller.loadData();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการโปรโมชั่น (Promotions)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: controller.loadData),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.promotions.isEmpty
              ? const Center(child: Text('ยังไม่มีโปรโมชั่นในระบบ'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.promotions.length,
                  itemBuilder: (context, index) {
                    final p = state.promotions[index];

                    String conditionStr = 'ตามยอดรวม';
                    if (p.conditions.containsKey('buy_items')) conditionStr = 'ซื้อสินค้ากำหนด';
                    if (p.conditions.containsKey('target_products')) conditionStr = 'ลดเฉพาะสินค้า';

                    String rewardStr = 'ลดเป็นบาท';
                    if (p.rewards.containsKey('discount_percent')) rewardStr = 'ลดเป็นเปอร์เซ็นต์';
                    if (p.rewards.containsKey('get_items')) rewardStr = 'แถมฟรีสินค้า';

                    return Card(
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: p.isActive ? Colors.black : Colors.grey,
                                  decoration: p.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Pri: ${p.priority}', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('เงื่อนไข: $conditionStr → รางวัล: $rewardStr', style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                'ระยะเวลา: ${p.startDate != null ? DateFormat('dd/MM/yyyy').format(p.startDate!) : 'ไม่ระบุ'} - ${p.endDate != null ? DateFormat('dd/MM/yyyy').format(p.endDate!) : 'ไม่ระบุ'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (p.startTime != null && p.endTime != null)
                                Text(
                                  'เวลา: ${p.startTime} - ${p.endTime}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: p.isActive,
                              onChanged: (val) => controller.toggleStatus(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => showDialogAndRefresh(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('ยืนยันการลบ'),
                                    content: Text('คุณต้องการลบ "${p.name}" ใช่หรือไม่?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('ลบข้อมูล', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await controller.deletePromotion(p.id);
                                  if (context.mounted) {
                                    SnackbarUtils.showLeft(context, '🗑️ ลบข้อมูลโปรโมชั่นเรียบร้อย');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () => showDialogAndRefresh(p),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialogAndRefresh(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มโปรโมชั่น'),
      ),
    );
  }
}
