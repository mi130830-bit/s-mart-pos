import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/shortage_provider.dart';
import 'widgets/stock_alert_entry_form.dart';
import 'tabs/stock_alert_open_tab.dart';
import 'tabs/stock_alert_low_stock_tab.dart';
import 'tabs/stock_alert_ordered_tab.dart';

class StockAlertScreen extends StatefulWidget {
  const StockAlertScreen({super.key});

  @override
  State<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends State<StockAlertScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ShortageProvider>(context, listen: false).loadShortages();
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
    return Consumer<ShortageProvider>(
      builder: (context, provider, child) {
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
                      Text('รอจัดการ (${provider.openShortages.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('ของหมด (${provider.lowStockProducts.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 6),
                      Text('สั่งแล้ว (${provider.orderedShortages.length})'),
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
      },
    );
  }
}
