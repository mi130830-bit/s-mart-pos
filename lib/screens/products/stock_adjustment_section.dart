import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/custom_buttons.dart';
import 'controllers/stock_adjustment_controller.dart';
import 'dialogs/add_adjustment_item_dialog.dart';
import 'stock_ledger_views.dart';
import 'widgets/adjustment_item_list.dart';

class StockAdjustmentSection extends StatefulWidget {
  const StockAdjustmentSection({super.key});

  @override
  State<StockAdjustmentSection> createState() => _StockAdjustmentSectionState();
}

class _StockAdjustmentSectionState extends State<StockAdjustmentSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabMgr;

  @override
  void initState() {
    super.initState();
    _tabMgr = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabMgr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header & Tabs
        Container(
          color: Colors.indigo.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabMgr,
                  isScrollable: true,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.playlist_add_check),
                      text: 'ทำรายการเช็ค (Check Stock)',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'ประวัติการเช็ค (History)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabMgr,
            children: const [
              _CheckStockPage(),
              StockAdjustmentHistoryView(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckStockPage extends ConsumerWidget {
  const _CheckStockPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockAdjustmentProvider);
    final controller = ref.read(stockAdjustmentProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการเช็คสต็อก (Stock Check)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  CustomButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AddAdjustmentItemDialog(),
                      );
                    },
                    icon: Icons.playlist_add_check,
                    label: 'เพิ่มรายการเช็ค',
                    type: ButtonType.primary,
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    onPressed: () => controller.openCloudImportDialog(context),
                    icon: Icons.cloud_download,
                    label: 'ดึงใบงาน S_MartPOS',
                    backgroundColor: Colors.teal,
                    type: ButtonType.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        const Expanded(
          child: AdjustmentItemList(),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                blurRadius: 5,
                offset: const Offset(0, -3))
          ]),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: CustomButton(
              onPressed: state.pendingItems.isEmpty
                  ? null
                  : () => controller.saveAllAdjustments(context),
              icon: Icons.save,
              label: 'บันทึกผลการตรวจนับ (${state.pendingItems.length})',
              type: ButtonType.primary,
              backgroundColor: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
