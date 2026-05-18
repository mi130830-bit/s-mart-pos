import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dashboard_stat_cards.dart';

/// ส่วนแสดงสถิติรายชั่วโมงและช่วงเวลาของวัน (Advanced Analytics)
class DashboardTimeStatsSection extends StatelessWidget {
  final Map<int, double> hourlySales;
  final Map<String, double> timeOfDaySales;

  const DashboardTimeStatsSection({
    super.key,
    required this.hourlySales,
    required this.timeOfDaySales,
  });

  @override
  Widget build(BuildContext context) {
    final formatMoney = NumberFormat("#,##0");

    int peakHour = -1;
    double peakAmount = 0;
    if (hourlySales.isNotEmpty) {
      final peak =
          hourlySales.entries.reduce((a, b) => a.value > b.value ? a : b);
      peakHour = peak.key;
      peakAmount = peak.value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('เจาะลึกพฤติกรรมการซื้อ (Advanced Analytics)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Time of Day Cards
        Row(
          children: [
            DashboardSmallStatCard(
              title: 'ช่วงเช้า (06-12)',
              value: timeOfDaySales['Morning'] ?? 0.0,
              icon: Icons.wb_sunny,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            DashboardSmallStatCard(
              title: 'ช่วงบ่าย (12-17)',
              value: timeOfDaySales['Afternoon'] ?? 0.0,
              icon: Icons.wb_cloudy,
              color: Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Hourly Bar Chart
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ยอดขายรายชั่วโมง',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (peakHour != -1)
                    Text(
                        '🔥 ช่วงพีค: $peakHour:00 น. (฿${formatMoney.format(peakAmount)})',
                        style:
                            TextStyle(color: Colors.red.shade700, fontSize: 12))
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(BarChartData(
                  barGroups: List.generate(24, (index) {
                    if (index < 6) return null;
                    final amt = hourlySales[index] ?? 0.0;
                    return BarChartGroupData(x: index, barRods: [
                      BarChartRodData(
                        toY: amt,
                        color: index == peakHour
                            ? Colors.red
                            : Colors.indigo.shade300,
                        width: 8,
                        borderRadius: BorderRadius.circular(2),
                      )
                    ]);
                  }).whereType<BarChartGroupData>().toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final h = val.toInt();
                        if (h % 3 == 0) {
                          return Text('$h:00',
                              style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox();
                      },
                      interval: 1,
                    )),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.black87,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                                '${group.x}:00 น.\n฿${formatMoney.format(rod.toY)}',
                                const TextStyle(color: Colors.white));
                          })),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
