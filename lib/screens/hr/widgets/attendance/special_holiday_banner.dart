import 'package:flutter/material.dart';

/// Banner widget for special holidays displayed in the Attendance tab.
/// Extracted from _HrAttendanceTabState._buildSpecialHolidayBanner.
class SpecialHolidayBanner extends StatelessWidget {
  final List<dynamic> holidays;

  const SpecialHolidayBanner({super.key, required this.holidays});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayHoliday = holidays.where((h) {
      final d = h.date;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).firstOrNull;

    if (todayHoliday == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access, color: Colors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '🏖️ วันหยุดพิเศษ: ${todayHoliday.name} — พนักงานรายเดือนไม่นับขาดงานวันนี้',
              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
