import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../screens/reports/fuel_summary_screen.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_stat_cards.dart';
import '../widgets/dashboard_credit_table.dart';
import '../widgets/dashboard_time_stats.dart';

/// แท็บ 2: "สรุปยอดขาย" — การ์ดสถิติ, กราฟช่วงเวลา, ยอดเชื่อ, ช่วงเดือน/ปี
class DashboardSummaryTab extends ConsumerWidget {
  const DashboardSummaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
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
                  'สรุปยอดขายวันที่ ${DateFormat('dd/MM/yyyy').format(state.selectedDate)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => notifier.prevDate(),
                    tooltip: 'วันก่อนหน้า',
                  ),
                  TextButton.icon(
                    onPressed: () => notifier.pickDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label:
                        Text(DateFormat('dd/MM/yyyy').format(state.selectedDate)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: notifier.isSameDay(state.selectedDate, DateTime.now()) 
                        ? null 
                        : () => notifier.nextDate(),
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
                  value: '฿${moneyFmt.format(state.todaySales)}',
                  color: Colors.blue,
                  icon: Icons.monetization_on,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DashboardStatCard(
                  title: 'บิลวันนี้',
                  value: '${state.todayOrders} ใบ',
                  color: Colors.orange,
                  icon: Icons.receipt,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DashboardStatCard(
                  title: 'กำไร (Gross)',
                  value: '฿${moneyFmt.format(state.todayProfit)}',
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
            hourlySales: state.hourlySales,
            timeOfDaySales: state.timeOfDaySales,
          ),
          const SizedBox(height: 32),

          // ── Credit Summary ───────────────────────────────────────────────────
          const Text('สรุปยอดขายเชื่อ (ค้างรับ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DashboardCreditTable(
            creditStatsToday: state.creditStatsToday,
            creditStatsWeek: state.creditStatsWeek,
            creditStatsMonth: state.creditStatsMonth,
            creditStatsYear: state.creditStatsYear,
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
                selectedPeriod: state.selectedPeriod,
                onChanged: (p) => notifier.changePeriod(p),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DashboardRangeSummaryCards(
            rangeSales: state.rangeSales,
            rangeProfit: state.rangeProfit,
            rangeOrders: state.rangeOrders,
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
