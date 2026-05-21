import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/reward_management_controller.dart';
import 'tabs/reward_catalog_tab.dart';
import 'tabs/reward_pending_tab.dart';
import 'tabs/reward_history_tab.dart';
import 'dialogs/reward_form_dialog.dart';

class RewardManagementScreen extends ConsumerStatefulWidget {
  const RewardManagementScreen({super.key});

  @override
  ConsumerState<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends ConsumerState<RewardManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final controller = ref.read(rewardManagementProvider.notifier);
      if (_tabController.index == 1 || _tabController.index == 2) {
        controller.loadRedemptions();
      } else {
        controller.loadRewards();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRewardForm() {
    final controller = ref.read(rewardManagementProvider.notifier);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RewardFormDialog(
        onSave: (savedReward) async {
          final success = await controller.saveReward(savedReward);
          if (success) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ บันทึกของรางวัลสำเร็จ'), backgroundColor: Colors.green),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ เกิดข้อผิดพลาดในการบันทึก'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardManagementProvider);
    final controller = ref.read(rewardManagementProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('จัดการของรางวัล'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: controller.loadAll, tooltip: 'รีเฟรช'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(icon: Icon(Icons.card_giftcard), text: 'แค็ตตาล็อก'),
            Tab(
              icon: Badge(
                isLabelVisible: state.pendingCount > 0,
                label: Text('${state.pendingCount}'),
                child: const Icon(Icons.inbox),
              ),
              text: 'รอจัดส่ง',
            ),
            const Tab(icon: Icon(Icons.history), text: 'ประวัติทั้งหมด'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: _showRewardForm,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('เพิ่มของรางวัล', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.blue.shade800,
              )
            : const SizedBox.shrink(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RewardCatalogTab(),
          RewardPendingTab(),
          RewardHistoryTab(),
        ],
      ),
    );
  }
}
