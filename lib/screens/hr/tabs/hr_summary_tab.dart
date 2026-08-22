import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../state/hr/advance_provider.dart';
import '../../../state/hr/dashboard_attendance_provider.dart';
import '../widgets/summary/hr_stat_card.dart';
import '../widgets/summary/hr_attendance_table.dart';

class HrSummaryTab extends ConsumerStatefulWidget {
  const HrSummaryTab({super.key});

  @override
  ConsumerState<HrSummaryTab> createState() => _HrSummaryTabState();
}

class _HrSummaryTabState extends ConsumerState<HrSummaryTab> {
  Timer? _attendanceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _attendanceRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => ref.invalidate(dashboardAttendanceProvider),
    );
  }

  @override
  void dispose() {
    _attendanceRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeeProvider);
    final advanceState = ref.watch(advanceProvider);

    final totalEmployees = empState.employees.where((e) => e.isActive).length;
    final totalDrivers = empState.employees
        .where((e) => e.isActive && e.roleType == 'DRIVER')
        .length;
    final pendingAdvances = advanceState.pending.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ภาพรวมทรัพยากรบุคคล (Dashboard)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // ✅ Using extracted HrStatCard widgets
          Row(
            children: [
              HrStatCard(
                title: 'พนักงานทั้งหมด',
                value: '$totalEmployees',
                subtitle: 'คนขับรถ $totalDrivers คน',
                icon: Icons.people,
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              HrStatCard(
                title: 'ขอเบิกล่วงหน้า',
                value: '$pendingAdvances',
                subtitle: 'รายการรออนุมัติ',
                icon: Icons.money,
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              HrStatCard(
                title: 'สถานะวันนี้',
                value: 'ปกติ',
                subtitle: 'ระบบทำงานสมบูรณ์',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '📅 สรุปเวลาเข้า-ออกงาน และวันลา',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final currentFilter =
                          ref.watch(dashboardAttendanceFilterProvider);
                      return DropdownButton<String>(
                        value: currentFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: 'DAY', child: Text('รายวัน (วันนี้)')),
                          DropdownMenuItem(
                              value: 'WEEK', child: Text('รายสัปดาห์')),
                          DropdownMenuItem(
                              value: 'MONTH', child: Text('รายเดือน')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(
                                    dashboardAttendanceFilterProvider.notifier)
                                .state = val;
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'รีเฟรชข้อมูล',
                onPressed: () {
                  ref.invalidate(dashboardAttendanceProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Using extracted HrAttendanceTable widget
          const Expanded(child: HrAttendanceTable()),
        ],
      ),
    );
  }
}
