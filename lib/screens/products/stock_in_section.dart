import 'package:flutter/material.dart';
import '../../widgets/common/custom_buttons.dart';
import 'stock_in/tabs/purchase_order_list_tab.dart';
import 'stock_in/tabs/purchase_order_history_tab.dart';
import 'stock_in/tabs/supplier_summary_tab.dart';
import 'stock_in/pages/stock_in_create_page.dart';

export 'stock_in/models/stock_in_item.dart';

class StockInSection extends StatefulWidget {
  const StockInSection({super.key});

  @override
  State<StockInSection> createState() => _StockInSectionState();
}

class _StockInSectionState extends State<StockInSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabMgr;

  @override
  void initState() {
    super.initState();
    _tabMgr = TabController(length: 3, vsync: this);
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
                    Tab(icon: Icon(Icons.assignment_outlined), text: 'ใบสั่งซื้อ (Purchase Orders)'),
                    Tab(icon: Icon(Icons.history), text: 'ประวัติรับเข้า (Received)'),
                    Tab(icon: Icon(Icons.pie_chart), text: 'สรุปตามผู้ขาย (Supplier)'),
                  ],
                ),
              ),
              CustomButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('สร้างรายการใหม่')),
                        body: const StockInCreatePage(),
                      ),
                    ),
                  ).then((val) {
                    if (val != null) {
                      setState(() {});
                      if (val == 'RECEIVED') _tabMgr.animateTo(1);
                    }
                  });
                },
                icon: Icons.add,
                label: 'สร้างใบสั่ง/รับของ',
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabMgr,
            children: [
              PurchaseOrderListTab(onRefresh: () => setState(() {})),
              const PurchaseOrderHistoryTab(),
              const SupplierSummaryTab(),
            ],
          ),
        ),
      ],
    );
  }
}