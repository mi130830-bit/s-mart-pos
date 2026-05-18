import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/sales_repository.dart';
import '../../repositories/debtor_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../services/ai_service.dart';
import '../../services/alert_service.dart';
import '../../services/settings_service.dart';
import '../../services/excel_export_service.dart';
import '../pos/pos_state_manager.dart';
import '../../state/auth_provider.dart';
import '../../widgets/dialogs/admin_pin_dialog.dart';
import '../../widgets/sync_status_widget.dart';
import '../reports/financial_report_screen.dart';
import '../reports/best_selling_screen.dart';
import '../customers/customer_search_dialog.dart';
import '../../models/customer.dart';

// Tabs
import 'tabs/dashboard_daily_tab.dart';
import 'tabs/dashboard_summary_tab.dart';
import 'tabs/dashboard_ai_tab.dart';

// Dialogs
import 'dialogs/dashboard_delete_dialog.dart';
import 'dialogs/dashboard_order_detail_dialog.dart';
import 'dialogs/dashboard_reprint_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // ── Repositories / Services ──────────────────────────────────────────────────
  final SalesRepository _salesRepo = SalesRepository();
  final DebtorRepository _debtRepo = DebtorRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final AiService _aiService = AiService();

  // ── State ────────────────────────────────────────────────────────────────────
  late TabController _tabController;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  // Daily
  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  int _todayOrders = 0;
  List<Map<String, dynamic>> _recentOrders = [];

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;

  // Analytics
  final Map<int, double> _hourlySales = {};
  Map<String, double> _timeOfDaySales = {'Morning': 0.0, 'Afternoon': 0.0};

  // Credit stats
  Map<String, dynamic> _creditStatsToday = {'amount': 0.0, 'count': 0};
  Map<String, dynamic> _creditStatsWeek = {'amount': 0.0, 'count': 0};
  Map<String, dynamic> _creditStatsMonth = {'amount': 0.0, 'count': 0};
  Map<String, dynamic> _creditStatsYear = {'amount': 0.0, 'count': 0};

  // Period / AI
  String _selectedPeriod = 'MONTH';
  List<Map<String, dynamic>> _filteredStats = [];
  double _rangeSales = 0.0;
  double _rangeProfit = 0.0;
  int _rangeOrders = 0;
  String _aiAnalysis = '';
  bool _isAnalyzing = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final start = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      final end = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

      final orders = await _salesRepo.getOrdersByDateRange(start, end);
      double todaySales = 0.0;
      int todayOrderCount = 0;
      for (var o in orders) {
        if (o['type']?.toString() == 'ORDER') {
          todaySales += double.tryParse(o['amount'].toString()) ?? 0.0;
          todayOrderCount++;
        }
      }
      _processTimeStats(orders);

      final todayStats =
          await _salesRepo.getSalesStatsByDateRange(start, end, 'DAILY');
      double todayProfit = 0.0;
      if (todayStats.isNotEmpty) {
        todayProfit =
            (double.tryParse(todayStats.first['totalSales'].toString()) ?? 0) -
                (double.tryParse(todayStats.first['totalCost'].toString()) ?? 0);
      }

      await _loadPeriodStats(resetLoading: false);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay =
          DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0);
      final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0);
      final yearStart = DateTime(now.year, 1, 1, 0, 0, 0);

      final credits = await Future.wait([
        _salesRepo.getCreditStats(todayStart, todayEnd),
        _salesRepo.getCreditStats(weekStartDay, todayEnd),
        _salesRepo.getCreditStats(monthStart, todayEnd),
        _salesRepo.getCreditStats(yearStart, todayEnd),
      ]);

      if (mounted) {
        setState(() {
          _recentOrders = orders;
          _todaySales = todaySales;
          _todayProfit = todayProfit;
          _todayOrders = todayOrderCount;
          _creditStatsToday = credits[0];
          _creditStatsWeek = credits[1];
          _creditStatsMonth = credits[2];
          _creditStatsYear = credits[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPeriodStats({bool resetLoading = true}) async {
    if (resetLoading) setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final start = _selectedPeriod == 'YEAR'
          ? DateTime(now.year, 1, 1)
          : DateTime(now.year, now.month, 1);
      final type = _selectedPeriod == 'YEAR' ? 'MONTHLY' : 'DAILY';
      final stats = await _salesRepo.getSalesStatsByDateRange(
          start, DateTime(now.year, now.month, now.day, 23, 59, 59), type);

      double rs = 0, rc = 0;
      int ro = 0;
      for (var s in stats) {
        rs += double.tryParse(s['totalSales'].toString()) ?? 0;
        rc += double.tryParse(s['totalCost'].toString()) ?? 0;
        ro += int.tryParse(s['orderCount'].toString()) ?? 0;
      }
      if (mounted) {
        setState(() {
          _filteredStats = stats;
          _rangeSales = rs;
          _rangeProfit = rs - rc;
          _rangeOrders = ro;
          if (resetLoading) _isLoading = false;
        });
      }
    } catch (e) {
      if (resetLoading && mounted) setState(() => _isLoading = false);
    }
  }

  void _processTimeStats(List<Map<String, dynamic>> orders) {
    _hourlySales.clear();
    _timeOfDaySales = {'Morning': 0.0, 'Afternoon': 0.0};
    for (var o in orders) {
      if (o['type'] != 'ORDER') continue;
      final date = DateTime.tryParse(o['createdAt'].toString());
      if (date == null) continue;
      final amount = double.tryParse(o['amount'].toString()) ?? 0.0;
      _hourlySales[date.hour] = (_hourlySales[date.hour] ?? 0) + amount;
      if (date.hour < 12) {
        _timeOfDaySales['Morning'] = (_timeOfDaySales['Morning']!) + amount;
      } else {
        _timeOfDaySales['Afternoon'] = (_timeOfDaySales['Afternoon']!) + amount;
      }
    }
  }

  // ── AI ───────────────────────────────────────────────────────────────────────

  Future<void> _fetchAiAnalysis() async {
    if (_isAnalyzing) return;
    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = 'กำลังวิเคราะห์ข้อมูลด้วย AI...';
    });
    try {
      final now = DateTime.now();
      final start = _selectedPeriod == 'YEAR'
          ? DateTime(now.year, 1, 1)
          : DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final topProducts =
          await _salesRepo.getTopProductsByDateRange(start, end, limit: 5);
      final topStr = topProducts
          .map((e) =>
              '- ${e['name']} (ขายได้ ${e['qty']} หน่วย, ยอด ${e['totalSales']} บาท)')
          .join('\n');

      String csv = 'ข้อมูลสรุปยอดขาย:\nวันที่,ยอดขาย,ต้นทุน,กำไร\n';
      for (var s in _filteredStats) {
        double sales = double.tryParse(s['totalSales'].toString()) ?? 0;
        double cost = double.tryParse(s['totalCost'].toString()) ?? 0;
        csv += '${s['label']},$sales,$cost,${sales - cost}\n';
      }
      csv += '\nสินค้าขายดี 5 อันดับ:\n$topStr';
      csv += '\nช่วงเช้า: ฿${_timeOfDaySales['Morning']}';
      csv += '\nช่วงบ่าย: ฿${_timeOfDaySales['Afternoon']}';
      if (_hourlySales.isNotEmpty) {
        final peak =
            _hourlySales.entries.reduce((a, b) => a.value > b.value ? a : b);
        csv += '\nช่วงเวลาพีค: ${peak.key}:00 (฿${peak.value})';
      }

      final result = await _aiService.predictSales(csv);
      if (mounted) setState(() { _aiAnalysis = result; _isAnalyzing = false; });
    } catch (e) {
      if (mounted) setState(() { _aiAnalysis = 'ไม่สามารถวิเคราะห์ได้: $e'; _isAnalyzing = false; });
    }
  }

  // ── Date Navigation ───────────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _prevDate() async {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    await _loadData();
  }

  Future<void> _nextDate() async {
    if (_isSameDay(_selectedDate, DateTime.now())) return;
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    await _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────────

  Future<void> _performSearch(String val) async {
    final query = val.trim();
    if (query.isEmpty) {
      setState(() { _searchQuery = ''; _searchResults = []; });
      return;
    }
    setState(() { _searchQuery = query; _isSearchLoading = true; });
    try {
      final results = await _salesRepo.searchOrders(query);
      if (mounted) setState(() { _searchResults = results; _isSearchLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchLoading = false);
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() { _searchQuery = ''; _searchResults = []; });
  }

  // ── Permission Helper ─────────────────────────────────────────────────────────

  Future<bool> _checkPermission(String action) async {
    final auth = context.read<AuthProvider>();
    if (auth.hasPermission(action)) return true;
    return AdminPinDialog.show(context,
        title: 'ยืนยันสิทธิ์',
        message: 'กรุณากรอกรหัสแอดมินเพื่อดำเนินการต่อ');
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _viewDetails(Map<String, dynamic> row) async {
    if (!await _checkPermission('history_view_detail') || !mounted) return;
    if (row['type'] == 'DEBT_PAYMENT') {
      await DashboardOrderDetailDialog.showDebtPayment(context,
          row: row, onViewLinkedOrder: (id) => _viewOrderById(id));
    } else {
      await DashboardOrderDetailDialog.show(context,
          orderId: int.tryParse(row['id'].toString()) ?? 0,
          salesRepo: _salesRepo);
    }
  }

  Future<void> _viewOrderById(int orderId) async {
    if (!await _checkPermission('history_view_detail') || !mounted) return;
    await DashboardOrderDetailDialog.show(context,
        orderId: orderId, salesRepo: _salesRepo);
  }

  Future<void> _reprintOrder(Map<String, dynamic> row) async {
    if (!mounted) return;
    if (row['type'] == 'DEBT_PAYMENT') {
      await DashboardReprintDialog.showDebtPayment(context,
          o: row, customerRepo: _customerRepo);
    } else {
      await DashboardReprintDialog.show(context,
          orderRow: row, salesRepo: _salesRepo);
    }
  }

  Future<void> _sendToDelivery(int orderId) async {
    if (!mounted) return;
    try {
      await context
          .read<PosStateManager>()
          .sendToDeliveryFromHistory(orderId, jobType: 'delivery');
      if (mounted) AlertService.show(context: context, message: 'ส่งข้อมูลไปฝ่ายจัดส่งเรียบร้อย', type: 'success');
    } catch (e) {
      if (mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
    }
  }

  Future<void> _sendToBackShop(int orderId) async {
    if (!mounted) return;
    try {
      await context
          .read<PosStateManager>()
          .sendToDeliveryFromHistory(orderId, jobType: 'pickup');
      if (mounted) AlertService.show(context: context, message: 'ส่งงาน "รับของหลังร้าน" เรียบร้อย', type: 'success');
    } catch (e) {
      if (mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
    }
  }

  Future<void> _changeCustomer(int orderId) async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasPermission('history_edit_customer')) {
      AlertService.show(context: context, message: 'คุณไม่มีสิทธิ์แก้ไขข้อมูลลูกค้าในประวัติการขาย', type: 'error');
      return;
    }
    if (!mounted) return;
    final customer = await showDialog<Customer>(
        context: context, builder: (_) => const CustomerSearchDialog());
    if (customer != null && mounted) {
      try {
        await _salesRepo.updateOrderCustomer(orderId, customer.id);
        if (mounted) {
          AlertService.show(context: context, message: 'อัปเดตข้อมูลลูกค้าเรียบร้อย', type: 'success');
          _loadData();
        }
      } catch (e) {
        if (mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> row) async {
    if (!await _checkPermission('history_delete_bill') || !mounted) return;

    final result = await DashboardDeleteDialog.show(context, orderRow: row);
    if (result == null || !mounted) return;

    // Security: ถ้าเปิด Toggle "บังคับรหัส Admin เมื่อลบบิล"
    if (SettingsService().requireAdminForVoid) {
      final orderId = int.tryParse(row['id'].toString()) ?? 0;
      final authorized = await AdminPinDialog.show(context,
          title: 'ยืนยันสิทธิ์ลบบิล',
          message: 'กรุณากรอกรหัส Admin เพื่อยืนยันการยกเลิกบิล #$orderId');
      if (!authorized || !mounted) return;
    }

    final orderId = int.tryParse(row['id'].toString()) ?? 0;
    final type = row['type'] ?? 'ORDER';

    try {
      if (type == 'DEBT_PAYMENT') {
        final success = await _debtRepo.deleteTransaction(orderId);
        if (success && mounted) {
          _loadData();
          AlertService.show(context: context, message: 'ลบรายการชำระหนี้เรียบร้อย', type: 'success');
        }
      } else {
        await _salesRepo.voidOrder(orderId,
            reason: result.reason, returnToStock: result.returnStock);
        if (mounted) {
          _loadData();
          AlertService.show(context: context, message: 'ยกเลิกบิลเรียบร้อย', type: 'success');
        }
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context,
            message: e.toString().replaceAll('Exception: ', ''), type: 'error');
      }
    }
  }

  Future<void> _exportDeliveryHistory(BuildContext context) async {
    final now = DateTime.now();
    final dateRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange:
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
    if (dateRange == null || !context.mounted) return;

    final start = DateTime(dateRange.start.year, dateRange.start.month,
        dateRange.start.day, 0, 0, 0);
    final end = DateTime(dateRange.end.year, dateRange.end.month,
        dateRange.end.day, 23, 59, 59);
    final success = await ExcelExportService().exportDeliveryHistory(start, end);
    if (context.mounted) {
      AlertService.show(
          context: context,
          message: success ? 'สร้างไฟล์ Excel สำเร็จ' : 'ไม่พบข้อมูลหรือมีข้อผิดพลาด',
          type: success ? 'success' : 'error');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final auth = Provider.of<AuthProvider>(context);
    final List<Tab> tabs = [];
    final List<Widget> tabViews = [];

    // Tab 1: รายการวันนี้
    tabs.add(const Tab(text: 'รายการวันนี้'));
    tabViews.add(DashboardDailyTab(
      selectedDate: _selectedDate,
      isToday: _isSameDay(_selectedDate, DateTime.now()),
      orders: _searchQuery.isNotEmpty ? _searchResults : _recentOrders,
      searchQuery: _searchQuery,
      isSearchLoading: _isSearchLoading,
      searchCtrl: _searchCtrl,
      searchFocus: _searchFocus,
      onPrevDate: _prevDate,
      onNextDate: _nextDate,
      onPickDate: _pickDate,
      onRefresh: _loadData,
      onViewDetails: _viewDetails,
      onReprint: _reprintOrder,
      onSendToDelivery: _sendToDelivery,
      onSendToBackShop: _sendToBackShop,
      onChangeCustomer: _changeCustomer,
      onDelete: _deleteOrder,
      onSearch: _performSearch,
      onClearSearch: _clearSearch,
    ));

    // Tab 2: สรุปยอดขาย
    if (auth.hasPermission('dashboard_view_summary')) {
      tabs.add(const Tab(text: 'สรุปยอดขาย'));
      tabViews.add(DashboardSummaryTab(
        selectedDate: _selectedDate,
        isToday: _isSameDay(_selectedDate, DateTime.now()),
        todaySales: _todaySales,
        todayProfit: _todayProfit,
        todayOrders: _todayOrders,
        creditStatsToday: _creditStatsToday,
        creditStatsWeek: _creditStatsWeek,
        creditStatsMonth: _creditStatsMonth,
        creditStatsYear: _creditStatsYear,
        hourlySales: _hourlySales,
        timeOfDaySales: _timeOfDaySales,
        rangeSales: _rangeSales,
        rangeProfit: _rangeProfit,
        rangeOrders: _rangeOrders,
        selectedPeriod: _selectedPeriod,
        onPrevDate: _prevDate,
        onNextDate: _nextDate,
        onPickDate: _pickDate,
        onPeriodChanged: (p) {
          setState(() => _selectedPeriod = p);
          _loadPeriodStats();
        },
      ));
    }

    // Tab 3: สรุปบัญชีการเงิน
    if (auth.hasPermission('dashboard_view_trend')) {
      tabs.add(const Tab(text: 'สรุปบัญชีการเงิน'));
      tabViews.add(const FinancialReportScreen(isEmbedded: true));
    }

    // Tab 4: วิเคราะห์ AI
    if (auth.hasPermission('dashboard_view_ai')) {
      tabs.add(const Tab(text: 'วิเคราะห์ AI'));
      tabViews.add(DashboardAiTab(
        aiAnalysis: _aiAnalysis,
        isAnalyzing: _isAnalyzing,
        onStart: _fetchAiAnalysis,
        onRefresh: _fetchAiAnalysis,
      ));
    }

    // Tab 5: สินค้าขายดี
    if (auth.hasPermission('dashboard_view_best_selling')) {
      tabs.add(const Tab(text: 'สินค้าขายดี'));
      tabViews.add(const BestSellingScreen(isEmbedded: true));
    }

    // Sync TabController length
    if (_tabController.length != tabs.length) {
      _tabController.dispose();
      _tabController =
          TabController(length: tabs.length, vsync: this, initialIndex: 0);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ภาพรวมธุรกิจและประวัติการขาย',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
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
            onPressed: () => _exportDeliveryHistory(context),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          const SizedBox(width: 10),
        ],
      ),
      body: TabBarView(controller: _tabController, children: tabViews),
    );
  }
}
