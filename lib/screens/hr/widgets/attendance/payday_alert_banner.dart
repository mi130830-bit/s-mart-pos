import 'package:flutter/material.dart';

/// Banner widget that alerts staff about upcoming payroll deadlines.
/// Extracted from HrScreen body — shown on Saturday (weekly) or 1st of month (monthly).
class PaydayAlertBanner extends StatelessWidget {
  const PaydayAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isWeeklyPayday = now.weekday == DateTime.saturday;
    final isMonthlyPayday = now.day == 1;

    if (isWeeklyPayday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: Colors.orange.shade100,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'แจ้งเตือน: วันนี้ครบกำหนดจ่ายค่าแรง "รายสัปดาห์" กรุณาไปที่แท็บ "เงินเดือน" เพื่อทำรายการ',
              style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (isMonthlyPayday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: Colors.blue.shade100,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'แจ้งเตือน: วันนี้ครบกำหนดจ่ายค่าแรง "รายเดือน" กรุณาไปที่แท็บ "เงินเดือน" เพื่อทำรายการ',
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
