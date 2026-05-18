import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../screens/reports/fuel_summary_screen.dart';
import '../widgets/dashboard_stat_cards.dart';
import '../widgets/dashboard_credit_table.dart';
import '../widgets/dashboard_time_stats.dart';

/// แท็บ 2: "สรุปยอดขาย" — การ์ดสถิติ, กราฟช่วงเวลา, ยอดเชื่อ, ช่วงเดือน/ปี
class DashboardSummaryTab extends StatelessWidget {
  final DateTime selectedDate;
  final bool isToday;
  final double todaySales;
  final double todayProfit;
  final int todayOrders;
  final Map<String, dynamic> creditStatsToday;
  final Map<String, dynamic> creditStatsWeek;
  final Map<String, dynamic> creditStatsMonth;
  final Map<String, dynamic> creditStatsYear;
  final Map<int, double> hourlySales;
  final Map<String, double> timeOfDaySales;
  final double rangeSales;
  final double rangeProfit;
  final int rangeOrders;
  final String selectedPeriod;

  // Callbacks
  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final VoidCallback onPickDate;
  final void Function(String period) onPeriodChanged;

  const DashboardSummaryTab({
    super.key,
    required this.selectedDate,
    required this.isToday,
    required this.todaySales,
    required this.todayProfit,
    required this.todayOrders,
    required this.creditStatsToday,
    required this.creditStatsWeek,
    required this.creditStatsMonth,
    required this.creditStatsYear,
    required this.hourlySales,
    required this.timeOfDaySales,
    required this.rangeSales,
    required this.rangeProfit,
    required this.rangeOrders,
    required this.selectedPeriod,
    required this.onPrevDate,
    required this.onNextDate,
    required this.onPickDate,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat('#,##0.00');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'สรุปยอดขายวันที่ ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onPrevDate,
                    tooltip: 'วันก่อนหน้า',
                  ),
                  TextButton.icon(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label:
                        Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: isToday ? null : onNextDate,
                    tooltip: 'วันถัดไป',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Today Stat Cards ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  title: 'ยอดขายวันนี้',
                  value: '฿${moneyFmt.format(todaySales)}',
                  color: Colors.blue,
                  icon: Icons.monetization_on,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DashboardStatCard(
                  title: 'บิลวันนี้',
                  value: '$todayOrders ใบ',
                  color: Colors.orange,
                  icon: Icons.receipt,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DashboardStatCard(
                  title: 'กำไร (Gross)',
                  value: '฿${moneyFmt.format(todayProfit)}',
                  color: Colors.green,
                  icon: Icons.trending_up,
                  subtitle: 'ยอดขาย - ต้นทุนสินค้า',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Fuel Summary Button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FuelSummaryScreen()));
              },
              icon: const Icon(Icons.local_gas_station),
              label: const Text('สรุปน้ำมัน (Fuel Summary)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Hourly / Time of Day Stats ───────────────────────────────────────
          DashboardTimeStatsSection(
            hourlySales: hourlySales,
            timeOfDaySales: timeOfDaySales,
          ),
          const SizedBox(height: 32),

          // ── Credit Summary ───────────────────────────────────────────────────
          const Text('สรุปยอดขายเชื่อ (ค้างรับ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DashboardCreditTable(
            creditStatsToday: creditStatsToday,
            creditStatsWeek: creditStatsWeek,
            creditStatsMonth: creditStatsMonth,
            creditStatsYear: creditStatsYear,
          ),
          const SizedBox(height: 32),

          // ── Period Selector + Range Summary ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('สรุปตามช่วงเวลา',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _PeriodSelector(
                selectedPeriod: selectedPeriod,
                onChanged: onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: 16),
          DashboardRangeSummaryCards(
            rangeSales: rangeSales,
            rangeProfit: rangeProfit,
            rangeOrders: rangeOrders,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'ส่วนนี้สรุปยอดขายและกำไรเปรียบเทียบระหว่าง วันนี้ และ ช่วงเวลาที่คุณเลือก',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final void Function(String period) onChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'MONTH', label: Text('เดือนนี้')),
        ButtonSegment(value: 'YEAR', label: Text('ปีนี้')),
      ],
      selected: {selectedPeriod},
      onSelectionChanged: (Set<String> newSelection) {
        onChanged(newSelection.first);
      },
    );
  }
}
