import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_provider.dart';
import '../../widgets/sync_status_widget.dart';
import '../reports/financial_report_screen.dart';
import '../reports/best_selling_screen.dart';

import 'controllers/dashboard_controller.dart';
import 'tabs/dashboard_daily_tab.dart';
import 'tabs/dashboard_summary_tab.dart';
import 'tabs/dashboard_ai_tab.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ใช้ select เพื่อดักฟังแค่ค่า isLoading เท่านั้น
    // ป้องกันการ Rebuild หน้าจอหลักและ AppBar พร่ำเพรื่อเมื่อข้อมูลส่วนอื่นอัปเดต
    final isLoading = ref.watch(dashboardProvider.select((state) => state.isLoading));
    final auth = ref.watch(authProvider);

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Tab> tabs = [];
    final List<Widget> tabViews = [];

    // Tab 1: รายการวันนี้
    tabs.add(const Tab(text: 'รายการวันนี้'));
    tabViews.add(const DashboardDailyTab());

    // Tab 2: สรุปยอดขาย
    if (auth.hasPermission('dashboard_view_summary')) {
      tabs.add(const Tab(text: 'สรุปยอดขาย'));
      tabViews.add(const DashboardSummaryTab());
    }

    // Tab 3: สรุปบัญชีการเงิน
    if (auth.hasPermission('dashboard_view_trend')) {
      tabs.add(const Tab(text: 'สรุปบัญชีการเงิน'));
      tabViews.add(const FinancialReportScreen(isEmbedded: true));
    }

    // Tab 4: วิเคราะห์ AI
    if (auth.hasPermission('dashboard_view_ai')) {
      tabs.add(const Tab(text: 'วิเคราะห์ AI'));
      tabViews.add(const DashboardAiTab());
    }

    // Tab 5: สินค้าขายดี
    if (auth.hasPermission('dashboard_view_best_selling')) {
      tabs.add(const Tab(text: 'สินค้าขายดี'));
      tabViews.add(const BestSellingScreen(isEmbedded: true));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('ภาพรวมธุรกิจและประวัติการขาย',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs,
            labelColor: Colors.indigo,
            indicatorColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
          ),
          actions: [
            const SyncStatusWidget(),
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined, color: Colors.orange),
              tooltip: 'ดาวน์โหลดรายงานการจัดส่ง (Excel)',
              onPressed: () => ref.read(dashboardProvider.notifier).exportDeliveryHistory(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh), 
              onPressed: () => ref.read(dashboardProvider.notifier).loadData(),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }
}
