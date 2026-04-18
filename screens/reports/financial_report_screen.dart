import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/purchase_repository.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final SalesRepository _salesRepo = SalesRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final PurchaseRepository _purchaseRepo = PurchaseRepository();

  bool _isLoading = false;

  // Filters
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String _viewMode = 'MONTHLY'; // 'MONTHLY', 'YEARLY'

  // Data
  double _totalSales = 0.0;
  double _totalCost = 0.0;
  double _totalExpenses = 0.0;
  double _totalIncome = 0.0;
  double _totalPurchases = 0.0;

  // Charts Data
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      DateTime start, end;

      if (_viewMode == 'MONTHLY') {
        start = DateTime(_selectedYear, _selectedMonth, 1);
        end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
      } else {
        start = DateTime(_selectedYear, 1, 1);
        end = DateTime(_selectedYear, 12, 31, 23, 59, 59);
      }

      // 1. Fetch Sales Stats
      final salesStats = await _salesRepo.getSalesStatsByDateRange(
          start, end, _viewMode == 'MONTHLY' ? 'DAILY' : 'MONTHLY');

      double sales = 0.0;
      double cost = 0.0;
      for (var s in salesStats) {
        sales += double.tryParse(s['totalSales'].toString()) ?? 0.0;
        cost += double.tryParse(s['totalCost'].toString()) ?? 0.0;
      }

      // 2. Fetch Expenses & Income
      final expenses =
          await _expenseRepo.getTotalExpensesByDateRange(start, end);
      final income = await _expenseRepo.getTotalIncomeByDateRange(start, end);

      // 3. Fetch Purchases (Stock In)
      final purchases =
          await _purchaseRepo.getTotalPurchasesByDateRange(start, end);

      if (mounted) {
        setState(() {
          _totalSales = sales;
          _totalCost = cost;
          _totalExpenses = expenses;
          _totalIncome = income;
          _totalPurchases = purchases;
          _chartData = salesStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Calculation Helpers
  double get _grossProfit => _totalSales - _totalCost;
  double get _netProfitCashFlow =>
      (_totalSales + _totalIncome) - (_totalPurchases + _totalExpenses);
  // Note: Some users prefer Net Profit = Gross Profit - Expenses.
  // But based on user request: "Net Profit (Sales - Buy - Expense)" implies Cash Flow logic.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปบัญชีการเงิน (Financial Report)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // View Mode Selector
          DropdownButton<String>(
            value: _viewMode,
            underline: Container(),
            items: const [
              DropdownMenuItem(value: 'MONTHLY', child: Text('รายเดือน')),
              DropdownMenuItem(value: 'YEARLY', child: Text('รายปี')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _viewMode = v);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 16),
          // Filter Selector
          if (_viewMode == 'MONTHLY') ...[
            DropdownButton<int>(
              value: _selectedMonth,
              underline: Container(),
              items: List.generate(12, (index) => index + 1)
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child:
                          Text(DateFormat('MMMM').format(DateTime(2022, m)))))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedMonth = v);
                  _loadData();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          DropdownButton<int>(
            value: _selectedYear,
            underline: Container(),
            items: List.generate(5, (index) => DateTime.now().year - index)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedYear = v);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Summary Cards Row
                  Row(
                    children: [
                      Expanded(
                          child: _buildSummaryCard('ยอดขาย (Sales)',
                              _totalSales, Colors.blue, Icons.monetization_on)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildSummaryCard('กำไรขั้นต้น (Gross)',
                              _grossProfit, Colors.green, Icons.trending_up,
                              subtitle:
                                  '${((_grossProfit / (_totalSales == 0 ? 1 : _totalSales)) * 100).toStringAsFixed(1)}% margin')),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildSummaryCard(
                              'รายจ่ายรวม',
                              _totalExpenses + _totalPurchases,
                              Colors.red,
                              Icons.money_off,
                              subtitle:
                                  'ซื้อของ: ${_f(_totalPurchases)} / จ่าย: ${_f(_totalExpenses)}')),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildSummaryCard('รายรับอื่นๆ', _totalIncome,
                              Colors.teal, Icons.add_circle)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Net Profit Highlight
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _netProfitCashFlow >= 0
                          ? Colors.teal.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _netProfitCashFlow >= 0
                              ? Colors.teal.shade200
                              : Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              'กำไรสุทธิ (Net Profit)',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '฿${_f(_netProfitCashFlow)}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _netProfitCashFlow >= 0
                                    ? Colors.teal.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '(ยอดขาย + รายรับ) - (ต้นทุนซื้อของ + ค่าใช้จ่าย)',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Chart Section
                  Container(
                    height: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'กราฟแสดงแนวโน้ม (${_viewMode == 'MONTHLY' ? 'รายวัน' : 'รายเดือน'})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 24),
                        Expanded(child: _buildChart()),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
      String title, double value, Color color, IconData icon,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_f(value),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) return const Center(child: Text('ไม่มีข้อมูล'));

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              // ✅ Fix: Adjust interval for daily view to prevent overcrowding
              interval: _viewMode == 'MONTHLY' && _chartData.length > 10
                  ? (_chartData.length / 5).toDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _chartData.length) {
                  return const SizedBox();
                }
                final label = _chartData[index]['label'];
                // Format label based on view mode
                if (_viewMode == 'MONTHLY') {
                  // yyyy-MM-dd -> dd
                  return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(label.split('-').last,
                          style: const TextStyle(fontSize: 10)));
                } else {
                  // yyyy-MM -> MM
                  return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(label.split('-')[1],
                          style: const TextStyle(fontSize: 10)));
                }
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _chartData.asMap().entries.map((e) {
          final sales =
              double.tryParse(e.value['totalSales'].toString()) ?? 0.0;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                  toY: sales,
                  color: Colors.blue,
                  width: 12,
                  borderRadius: BorderRadius.circular(4)),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _f(double value) {
    return NumberFormat('#,##0.00').format(value);
  }
}
