import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/point_reward.dart';
import '../controllers/reward_management_controller.dart';
import '../dialogs/reward_form_dialog.dart';

class RewardCatalogTab extends ConsumerWidget {
  const RewardCatalogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rewardManagementProvider);
    final controller = ref.read(rewardManagementProvider.notifier);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.rewards.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 0.8, crossAxisSpacing: 16, mainAxisSpacing: 16,
        ),
        itemCount: state.rewards.length,
        itemBuilder: (context, index) {
          final reward = state.rewards[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showRewardForm(context, controller, reward),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (reward.imageUrl != null && reward.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: _buildLocalImage(reward.imageUrl!),
                            )
                          else
                            Icon(Icons.image_not_supported, size: 40, color: Colors.grey.shade400),
                          if (!reward.isActive)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Center(child: Text('ปิดใช้งาน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                              ),
                            ),
                          if (reward.isCoupon)
                            Positioned(
                              bottom: 6, left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('🎟️ คูปอง ฿${reward.discountValue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          Positioned(
                            top: 8, right: 8,
                            child: Row(children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white.withValues(alpha: 0.9),
                                child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _showRewardForm(context, controller, reward)),
                              ),
                              const SizedBox(width: 4),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white.withValues(alpha: 0.9),
                                child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteReward(context, controller, reward)),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reward.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('คงเหลือ: ${reward.stockQuantity} ชิ้น', style: TextStyle(color: reward.stockQuantity > 0 ? Colors.green.shade700 : Colors.red, fontSize: 13)),
                          const Spacer(),
                          Row(children: [
                            Icon(Icons.stars, size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text('${reward.pointPrice} แต้ม', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 15)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('ยังไม่มีของรางวัลในระบบ', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('กดเพิ่มของรางวัลด้านล่างขวาเพื่อเริ่มต้น', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLocalImage(String relativeUrl) {
    final fileName = relativeUrl.split('/').last;
    final String baseDir = Directory.current.path;
    final String localPath = '$baseDir\\backend\\public\\rewards\\$fileName';
    final file = File(localPath);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    return Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400);
  }

  void _showRewardForm(BuildContext context, RewardManagementController controller, PointReward reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RewardFormDialog(
        initialReward: reward,
        onSave: (savedReward) async {
          final success = await controller.saveReward(savedReward);
          if (success) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ บันทึกของรางวัลสำเร็จ'), backgroundColor: Colors.green),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ เกิดข้อผิดพลาดในการบันทึก'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteReward(BuildContext context, RewardManagementController controller, PointReward reward) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบ "${reward.name}" ใช่หรือไม่?'),
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
      final success = await controller.deleteReward(reward.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ ลบข้อมูลเรียบร้อย'), backgroundColor: Colors.orange),
        );
      }
    }
  }
}
