import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeliverySummaryCards extends StatelessWidget {
  final int totalJobs;
  final double totalDistance;
  final double totalAmount;
  final double totalFuelCost;
  final int missingDistanceCount;

  const DeliverySummaryCards({
    super.key,
    required this.totalJobs,
    required this.totalDistance,
    required this.totalAmount,
    required this.totalFuelCost,
    required this.missingDistanceCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFormat = NumberFormat('#,##0.00');

    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SummaryCard(
            label: 'งานทั้งหมด',
            value: '$totalJobs งาน',
            icon: Icons.local_shipping_outlined,
            color: Colors.indigo,
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            label: 'ระยะทางรวม',
            value: '${moneyFormat.format(totalDistance)} กม.',
            icon: Icons.route_outlined,
            color: Colors.blue,
            subtitle: '* จากข้อมูลลูกค้าในระบบ',
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            label: 'ยอดเงินรวม',
            value: '฿${moneyFormat.format(totalAmount)}',
            icon: Icons.payments_outlined,
            color: Colors.green,
            large: true,
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            label: 'ค่าน้ำมันรวม',
            value: '฿${moneyFormat.format(totalFuelCost)}',
            icon: Icons.local_gas_station_outlined,
            color: Colors.orange,
          ),
          if (missingDistanceCount > 0) ...[
            const SizedBox(width: 10),
            _SummaryCard(
              label: 'ไม่มีระยะทาง',
              value: '$missingDistanceCount รายการ',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              subtitle: 'กรอกระยะทางในข้อมูลลูกค้า',
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool large;
  final String? subtitle;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.large = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: color, fontSize: 12)),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: large ? 18 : 15,
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
