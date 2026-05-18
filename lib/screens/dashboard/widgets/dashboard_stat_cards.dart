import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// การ์ดสถิติหลัก (ยอดขาย, บิล, กำไร ฯลฯ)
class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 24)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// การ์ดสถิติขนาดเล็กสำหรับยอดขายช่วงเวลา (เช้า/บ่าย)
class DashboardSmallStatCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;

  const DashboardSmallStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            Text('฿${NumberFormat("#,##0").format(value)}',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// การ์ดสรุปช่วงเวลา (เดือนนี้/ปีนี้)
class DashboardRangeSummaryCards extends StatelessWidget {
  final double rangeSales;
  final double rangeProfit;
  final int rangeOrders;

  const DashboardRangeSummaryCards({
    super.key,
    required this.rangeSales,
    required this.rangeProfit,
    required this.rangeOrders,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat("#,##0");
    return Row(
      children: [
        _RangeSmallCard(
            title: 'ยอดขายช่วงนี้',
            value: '฿${format.format(rangeSales)}',
            color: Colors.indigo),
        const SizedBox(width: 12),
        _RangeSmallCard(
            title: 'กำไรช่วงนี้',
            value: '฿${format.format(rangeProfit)}',
            color: Colors.teal),
        const SizedBox(width: 12),
        _RangeSmallCard(
            title: 'จำนวนบิล',
            value: '${format.format(rangeOrders)} บิล',
            color: Colors.orange),
      ],
    );
  }
}

class _RangeSmallCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _RangeSmallCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
