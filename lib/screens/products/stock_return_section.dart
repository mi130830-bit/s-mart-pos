import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/custom_buttons.dart';
import 'controllers/stock_return_controller.dart';
import 'dialogs/add_return_item_dialog.dart';
import 'stock_ledger_views.dart';
import 'widgets/return_item_table.dart';

class StockReturnSection extends StatefulWidget {
  const StockReturnSection({super.key});

  @override
  State<StockReturnSection> createState() => _StockReturnSectionState();
}

class _StockReturnSectionState extends State<StockReturnSection>
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
        // Header & Tabs (สไตล์เดียวกับ Stock In)
        Container(
          color: Colors.orange.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabMgr,
                  isScrollable: true,
                  labelColor: Colors.deepOrange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepOrange,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.assignment_return),
                      text: 'ทำรายการคืน (Create Return)',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'ประวัติการรับคืน (History)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabMgr,
            children: const [
              // Tab 1: Create Return Page
              StockReturnCreatePage(),
              // Tab 2: History (Reuse Generic List)
              GenericStockHistoryList(transactionType: 'RETURN_IN'),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// หน้าจอทำรายการคืนสินค้า (Pure UI)
// ---------------------------------------------------------------------------
class StockReturnCreatePage extends ConsumerWidget {
  const StockReturnCreatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockReturnProvider);
    final controller = ref.read(stockReturnProvider.notifier);

    return Column(
      children: [
        // 1. Toolbar & Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'รายการสินค้าที่รับคืน (New Return List)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              CustomButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AddReturnItemDialog(),
                  );
                },
                icon: Icons.add_shopping_cart,
                label: 'เพิ่มรายการคืน (F1)',
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),

        // 2 & 3. Table Header & Content
        const Expanded(
          child: ReturnItemTable(),
        ),

        // 4. Footer Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ยอดเงินคืนรวม (Total Refund):',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      '฿${NumberFormat('#,##0.00').format(state.totalRefundAmount)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomButton(
                  onPressed: state.returnItems.isEmpty
                      ? null
                      : () => controller.saveReturnBatch(context),
                  icon: Icons.save,
                  label: 'บันทึกการคืน (Save Return)',
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
