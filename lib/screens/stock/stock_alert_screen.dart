import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/shortage_provider.dart';
import 'widgets/stock_alert_entry_form.dart';
import 'tabs/stock_alert_open_tab.dart';
import 'tabs/stock_alert_low_stock_tab.dart';
import 'tabs/stock_alert_ordered_tab.dart';

class StockAlertScreen extends ConsumerStatefulWidget {
  const StockAlertScreen({super.key});

  @override
  ConsumerState<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends ConsumerState<StockAlertScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(shortageProvider.notifier).loadShortages();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortage = ref.watch(shortageProvider);
    return Scaffold(
          appBar: AppBar(
            title: const Text('แจ้งของหมด / แจ้งซ่อม'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pending_actions, size: 18),
                      const SizedBox(width: 6),
                      Text('รอจัดการ (${shortage.openShortages.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('ของหมด (${shortage.lowStockProducts.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 6),
                      Text('สั่งแล้ว (${shortage.orderedShortages.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              const StockAlertEntryForm(),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    StockAlertOpenTab(),
                    StockAlertLowStockTab(),
                    StockAlertOrderedTab(),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}
