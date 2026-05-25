import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/sales_repository.dart';
import '../../../repositories/debtor_repository.dart';
import '../../../repositories/customer_repository.dart';
import '../../../services/ai_service.dart';
import '../../../services/alert_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/excel_export_service.dart';
import '../../pos/pos_state_manager.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/dialogs/admin_pin_dialog.dart';
import '../dialogs/dashboard_delete_dialog.dart';
import '../dialogs/dashboard_order_detail_dialog.dart';
import '../dialogs/dashboard_reprint_dialog.dart';
import '../../customers/customer_search_dialog.dart';
import '../../../models/customer.dart';

@immutable
class DashboardState {
  final bool isLoading;
  final DateTime selectedDate;
  final double todaySales;
  final double todayProfit;
  final int todayOrders;
  final List<Map<String, dynamic>> recentOrders;
  final String searchQuery;
  final List<Map<String, dynamic>> searchResults;
  final bool isSearchLoading;
  final Map<int, double> hourlySales;
  final Map<String, double> timeOfDaySales;
  final Map<String, dynamic> creditStatsToday;
  final Map<String, dynamic> creditStatsWeek;
  final Map<String, dynamic> creditStatsMonth;
  final Map<String, dynamic> creditStatsYear;
  final String selectedPeriod;
  final List<Map<String, dynamic>> filteredStats;
  final double rangeSales;
  final double rangeProfit;
  final int rangeOrders;
  final String aiAnalysis;
  final bool isAnalyzing;

  const DashboardState({
    this.isLoading = true,
    required this.selectedDate,
    this.todaySales = 0.0,
    this.todayProfit = 0.0,
    this.todayOrders = 0,
    this.recentOrders = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearchLoading = false,
    this.hourlySales = const {},
    this.timeOfDaySales = const {'Morning': 0.0, 'Afternoon': 0.0},
    this.creditStatsToday = const {'amount': 0.0, 'count': 0},
    this.creditStatsWeek = const {'amount': 0.0, 'count': 0},
    this.creditStatsMonth = const {'amount': 0.0, 'count': 0},
    this.creditStatsYear = const {'amount': 0.0, 'count': 0},
    this.selectedPeriod = 'MONTH',
    this.filteredStats = const [],
    this.rangeSales = 0.0,
    this.rangeProfit = 0.0,
    this.rangeOrders = 0,
    this.aiAnalysis = '',
    this.isAnalyzing = false,
  });

  DashboardState copyWith({
    bool? isLoading,
    DateTime? selectedDate,
    double? todaySales,
    double? todayProfit,
    int? todayOrders,
    List<Map<String, dynamic>>? recentOrders,
    String? searchQuery,
    List<Map<String, dynamic>>? searchResults,
    bool? isSearchLoading,
    Map<int, double>? hourlySales,
    Map<String, double>? timeOfDaySales,
    Map<String, dynamic>? creditStatsToday,
    Map<String, dynamic>? creditStatsWeek,
    Map<String, dynamic>? creditStatsMonth,
    Map<String, dynamic>? creditStatsYear,
    String? selectedPeriod,
    List<Map<String, dynamic>>? filteredStats,
    double? rangeSales,
    double? rangeProfit,
    int? rangeOrders,
    String? aiAnalysis,
    bool? isAnalyzing,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      selectedDate: selectedDate ?? this.selectedDate,
      todaySales: todaySales ?? this.todaySales,
      todayProfit: todayProfit ?? this.todayProfit,
      todayOrders: todayOrders ?? this.todayOrders,
      recentOrders: recentOrders ?? this.recentOrders,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      hourlySales: hourlySales ?? this.hourlySales,
      timeOfDaySales: timeOfDaySales ?? this.timeOfDaySales,
      creditStatsToday: creditStatsToday ?? this.creditStatsToday,
      creditStatsWeek: creditStatsWeek ?? this.creditStatsWeek,
      creditStatsMonth: creditStatsMonth ?? this.creditStatsMonth,
      creditStatsYear: creditStatsYear ?? this.creditStatsYear,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      filteredStats: filteredStats ?? this.filteredStats,
      rangeSales: rangeSales ?? this.rangeSales,
      rangeProfit: rangeProfit ?? this.rangeProfit,
      rangeOrders: rangeOrders ?? this.rangeOrders,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    );
  }
}

final dashboardProvider = NotifierProvider.autoDispose<DashboardNotifier, DashboardState>(DashboardNotifier.new);

class DashboardNotifier extends AutoDisposeNotifier<DashboardState> {
  final SalesRepository _salesRepo = SalesRepository();
  final DebtorRepository _debtRepo = DebtorRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final AiService _aiService = AiService();

  @override
  DashboardState build() {
    Future.microtask(() => loadData());
    return DashboardState(selectedDate: DateTime.now());
  }

  // ── Data Loading ─────────────────────────────────────────────────────────────

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final start = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 0, 0, 0);
      final end = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 23, 59, 59);

      final orders = await _salesRepo.getOrdersByDateRange(start, end);
      double tempTodaySales = 0.0;
      int tempTodayOrderCount = 0;
      for (var o in orders) {
        final double amount = double.tryParse(o['amount'].toString()) ?? 0.0;
        final String paymentMethod = o['paymentMethod']?.toString().toLowerCase() ?? '';
        
        if (o['type']?.toString() == 'ORDER') {
          if (o['status'] == 'COMPLETED' && paymentMethod != 'credit') {
            tempTodaySales += amount;
          }
          tempTodayOrderCount++;
        } else if (o['type']?.toString() == 'DEBT_PAYMENT') {
          tempTodaySales += amount;
        }
      }
      _processTimeStats(orders);

      final todayStats = await _salesRepo.getSalesStatsByDateRange(start, end, 'DAILY');
      double tempTodayProfit = 0.0;
      if (todayStats.isNotEmpty) {
        tempTodayProfit = (double.tryParse(todayStats.first['totalSales'].toString()) ?? 0) -
            (double.tryParse(todayStats.first['totalCost'].toString()) ?? 0);
      }

      await loadPeriodStats(resetLoading: false);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0);
      final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0);
      final yearStart = DateTime(now.year, 1, 1, 0, 0, 0);

      final credits = await Future.wait([
        _salesRepo.getCreditStats(todayStart, todayEnd),
        _salesRepo.getCreditStats(weekStartDay, todayEnd),
        _salesRepo.getCreditStats(monthStart, todayEnd),
        _salesRepo.getCreditStats(yearStart, todayEnd),
      ]);

      state = state.copyWith(
        recentOrders: orders,
        todaySales: tempTodaySales,
        todayProfit: tempTodayProfit,
        todayOrders: tempTodayOrderCount,
        creditStatsToday: credits[0],
        creditStatsWeek: credits[1],
        creditStatsMonth: credits[2],
        creditStatsYear: credits[3],
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadPeriodStats({bool resetLoading = true}) async {
    if (resetLoading) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final now = DateTime.now();
      final start = state.selectedPeriod == 'YEAR' ? DateTime(now.year, 1, 1) : DateTime(now.year, now.month, 1);
      final type = state.selectedPeriod == 'YEAR' ? 'MONTHLY' : 'DAILY';
      final stats = await _salesRepo.getSalesStatsByDateRange(
          start, DateTime(now.year, now.month, now.day, 23, 59, 59), type);

      double rs = 0, rc = 0;
      int ro = 0;
      for (var s in stats) {
        rs += double.tryParse(s['totalSales'].toString()) ?? 0;
        rc += double.tryParse(s['totalCost'].toString()) ?? 0;
        ro += int.tryParse(s['orderCount'].toString()) ?? 0;
      }

      state = state.copyWith(
        filteredStats: stats,
        rangeSales: rs,
        rangeProfit: rs - rc,
        rangeOrders: ro,
        isLoading: resetLoading ? false : state.isLoading,
      );
    } catch (e) {
      if (resetLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void _processTimeStats(List<Map<String, dynamic>> orders) {
    final Map<int, double> hourlySales = {};
    Map<String, double> timeOfDaySales = {'Morning': 0.0, 'Afternoon': 0.0};
    for (var o in orders) {
      if (o['type'] != 'ORDER' && o['type'] != 'DEBT_PAYMENT') continue;
      final String paymentMethod = o['paymentMethod']?.toString().toLowerCase() ?? '';
      if (o['type'] == 'ORDER' && (o['status'] != 'COMPLETED' || paymentMethod == 'credit')) continue;
      
      final date = DateTime.tryParse(o['createdAt'].toString());
      if (date == null) continue;
      final amount = double.tryParse(o['amount'].toString()) ?? 0.0;
      hourlySales[date.hour] = (hourlySales[date.hour] ?? 0) + amount;
      if (date.hour < 12) {
        timeOfDaySales['Morning'] = (timeOfDaySales['Morning']!) + amount;
      } else {
        timeOfDaySales['Afternoon'] = (timeOfDaySales['Afternoon']!) + amount;
      }
    }
    state = state.copyWith(
      hourlySales: hourlySales,
      timeOfDaySales: timeOfDaySales,
    );
  }

  // ── AI ───────────────────────────────────────────────────────────────────────

  Future<void> fetchAiAnalysis() async {
    if (state.isAnalyzing) return;
    state = state.copyWith(
      isAnalyzing: true,
      aiAnalysis: 'กำลังวิเคราะห์ข้อมูลด้วย AI...',
    );
    
    try {
      final now = DateTime.now();
      final start = state.selectedPeriod == 'YEAR' ? DateTime(now.year, 1, 1) : DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final topProducts = await _salesRepo.getTopProductsByDateRange(start, end, limit: 5);
      final topStr = topProducts
          .map((e) => '- ${e['name']} (ขายได้ ${e['qty']} หน่วย, ยอด ${e['totalSales']} บาท)')
          .join('\n');

      String csv = 'ข้อมูลสรุปยอดขาย:\nวันที่,ยอดขาย,ต้นทุน,กำไร\n';
      for (var s in state.filteredStats) {
        double sales = double.tryParse(s['totalSales'].toString()) ?? 0;
        double cost = double.tryParse(s['totalCost'].toString()) ?? 0;
        csv += '${s['label']},$sales,$cost,${sales - cost}\n';
      }
      csv += '\nสินค้าขายดี 5 อันดับ:\n$topStr';
      csv += '\nช่วงเช้า: ฿${state.timeOfDaySales['Morning']}';
      csv += '\nช่วงบ่าย: ฿${state.timeOfDaySales['Afternoon']}';
      if (state.hourlySales.isNotEmpty) {
        final peak = state.hourlySales.entries.reduce((a, b) => a.value > b.value ? a : b);
        csv += '\nช่วงเวลาพีค: ${peak.key}:00 (฿${peak.value})';
      }

      final aiAnalysis = await _aiService.predictSales(csv);
      state = state.copyWith(
        aiAnalysis: aiAnalysis,
        isAnalyzing: false,
      );
    } catch (e) {
      state = state.copyWith(
        aiAnalysis: 'ไม่สามารถวิเคราะห์ได้: $e',
        isAnalyzing: false,
      );
    }
  }

  // ── Date Navigation ───────────────────────────────────────────────────────────

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> prevDate() async {
    state = state.copyWith(selectedDate: state.selectedDate.subtract(const Duration(days: 1)));
    await loadData();
  }

  Future<void> nextDate() async {
    if (isSameDay(state.selectedDate, DateTime.now())) return;
    state = state.copyWith(selectedDate: state.selectedDate.add(const Duration(days: 1)));
    await loadData();
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: state.selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (picked != null && !isSameDay(picked, state.selectedDate)) {
      state = state.copyWith(selectedDate: picked);
      await loadData();
    }
  }

  void changePeriod(String p) {
    state = state.copyWith(selectedPeriod: p);
    loadPeriodStats();
  }

  // ── Search ────────────────────────────────────────────────────────────────────

  Future<void> performSearch(String val, BuildContext context) async {
    final query = val.trim();
    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchResults: [],
      );
      return;
    }
    state = state.copyWith(
      searchQuery: query,
      isSearchLoading: true,
    );
    try {
      final searchResults = await _salesRepo.searchOrders(query);
      state = state.copyWith(
        searchResults: searchResults,
        isSearchLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isSearchLoading: false);
      if (context.mounted) {
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      searchResults: [],
    );
  }

  // ── Permission Helper ─────────────────────────────────────────────────────────

  Future<bool> _checkPermission(BuildContext context, String action) async {
    final auth = ref.read(authProvider);
    if (auth.hasPermission(action)) return true;
    return AdminPinDialog.show(context,
        title: 'ยืนยันสิทธิ์',
        message: 'กรุณากรอกรหัสแอดมินเพื่อดำเนินการต่อ');
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> viewDetails(BuildContext context, Map<String, dynamic> row) async {
    if (!await _checkPermission(context, 'history_view_detail') || !context.mounted) return;
    if (row['type'] == 'DEBT_PAYMENT') {
      await DashboardOrderDetailDialog.showDebtPayment(context,
          row: row, onViewLinkedOrder: (id) => viewOrderById(context, id));
    } else {
      await DashboardOrderDetailDialog.show(context,
          orderId: int.tryParse(row['id'].toString()) ?? 0,
          salesRepo: _salesRepo);
    }
  }

  Future<void> viewOrderById(BuildContext context, int orderId) async {
    if (!await _checkPermission(context, 'history_view_detail') || !context.mounted) return;
    await DashboardOrderDetailDialog.show(context, orderId: orderId, salesRepo: _salesRepo);
  }

  Future<void> reprintOrder(BuildContext context, Map<String, dynamic> row) async {
    if (row['type'] == 'DEBT_PAYMENT') {
      await DashboardReprintDialog.showDebtPayment(context, o: row, customerRepo: _customerRepo);
    } else {
      await DashboardReprintDialog.show(context, orderRow: row, salesRepo: _salesRepo);
    }
  }

  Future<void> sendToDelivery(BuildContext context, int orderId) async {
    try {
      await ProviderScope.containerOf(context).read(posProvider.notifier).sendToDeliveryFromHistory(orderId, jobType: 'delivery');
      if (context.mounted) AlertService.show(context: context, message: 'ส่งข้อมูลไปฝ่ายจัดส่งเรียบร้อย', type: 'success');
    } catch (e) {
      if (context.mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
    }
  }

  Future<void> sendToBackShop(BuildContext context, int orderId) async {
    try {
      await ProviderScope.containerOf(context).read(posProvider.notifier).sendToDeliveryFromHistory(orderId, jobType: 'pickup');
      if (context.mounted) AlertService.show(context: context, message: 'ส่งงาน "รับของหลังร้าน" เรียบร้อย', type: 'success');
    } catch (e) {
      if (context.mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
    }
  }

  Future<void> changeCustomer(BuildContext context, int orderId) async {
    final auth = ref.read(authProvider);
    if (!auth.hasPermission('history_edit_customer')) {
      AlertService.show(context: context, message: 'คุณไม่มีสิทธิ์แก้ไขข้อมูลลูกค้าในประวัติการขาย', type: 'error');
      return;
    }
    final customer = await showDialog<Customer>(
        context: context, builder: (_) => const CustomerSearchDialog());
    if (customer != null && context.mounted) {
      try {
        await _salesRepo.updateOrderCustomer(orderId, customer.id);
        if (context.mounted) {
          AlertService.show(context: context, message: 'อัปเดตข้อมูลลูกค้าเรียบร้อย', type: 'success');
          loadData();
        }
      } catch (e) {
        if (context.mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  Future<void> deleteOrder(BuildContext context, Map<String, dynamic> row) async {
    if (!await _checkPermission(context, 'history_delete_bill') || !context.mounted) return;

    final result = await DashboardDeleteDialog.show(context, orderRow: row);
    if (result == null || !context.mounted) return;

    if (SettingsService().requireAdminForVoid) {
      final orderId = int.tryParse(row['id'].toString()) ?? 0;
      final authorized = await AdminPinDialog.show(context,
          title: 'ยืนยันสิทธิ์ลบบิล',
          message: 'กรุณากรอกรหัส Admin เพื่อยืนยันการยกเลิกบิล #$orderId');
      if (!authorized || !context.mounted) return;
    }

    final orderId = int.tryParse(row['id'].toString()) ?? 0;
    final type = row['type'] ?? 'ORDER';

    try {
      if (type == 'DEBT_PAYMENT') {
        final success = await _debtRepo.deleteTransaction(orderId);
        if (success && context.mounted) {
          loadData();
          AlertService.show(context: context, message: 'ลบรายการชำระหนี้เรียบร้อย', type: 'success');
        }
      } else {
        await _salesRepo.voidOrder(orderId, reason: result.reason, returnToStock: result.returnStock);
        if (context.mounted) {
          loadData();
          AlertService.show(context: context, message: 'ยกเลิกบิลเรียบร้อย', type: 'success');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AlertService.show(context: context, message: e.toString().replaceAll('Exception: ', ''), type: 'error');
      }
    }
  }

  Future<void> exportDeliveryHistory(BuildContext context) async {
    final now = DateTime.now();
    final dateRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
    if (dateRange == null || !context.mounted) return;

    final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day, 0, 0, 0);
    final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
    final success = await ExcelExportService().exportDeliveryHistory(start, end);
    if (context.mounted) {
      AlertService.show(
          context: context,
          message: success ? 'สร้างไฟล์ Excel สำเร็จ' : 'ไม่พบข้อมูลหรือมีข้อผิดพลาด',
          type: success ? 'success' : 'error');
    }
  }
}
