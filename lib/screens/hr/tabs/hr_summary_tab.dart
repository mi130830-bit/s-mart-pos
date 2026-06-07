import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../state/hr/advance_provider.dart';
import '../../../state/hr/dashboard_attendance_provider.dart';
import '../../../models/hr/dashboard_attendance_summary.dart';
import 'package:intl/intl.dart';
import '../../../services/hr/attendance_sync_service.dart';

class HrSummaryTab extends ConsumerStatefulWidget {
  const HrSummaryTab({super.key});

  @override
  ConsumerState<HrSummaryTab> createState() => _HrSummaryTabState();
}

class _HrSummaryTabState extends ConsumerState<HrSummaryTab> {
  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeeProvider);
    final advanceState = ref.watch(advanceProvider);

    final totalEmployees = empState.employees.where((e) => e.isActive).length;
    final totalDrivers = empState.employees.where((e) => e.isActive && e.roleType == 'DRIVER').length;
    
    // In a real app we would have a summary endpoint for these stats.
    // For now we use the loaded providers for demonstration.
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
          Row(
            children: [
              _buildStatCard(
                title: 'พนักงานทั้งหมด',
                value: '$totalEmployees',
                subtitle: 'คนขับรถ $totalDrivers คน',
                icon: Icons.people,
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'ขอเบิกล่วงหน้า',
                value: '$pendingAdvances',
                subtitle: 'รายการรออนุมัติ',
                icon: Icons.money,
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'สถานะวันนี้',
                value: 'ปกติ',
                subtitle: 'ระบบทำงานสมบูรณ์',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 32),
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
                      final currentFilter = ref.watch(dashboardAttendanceFilterProvider);
                      return DropdownButton<String>(
                        value: currentFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'DAY', child: Text('รายวัน (วันนี้)')),
                          DropdownMenuItem(value: 'WEEK', child: Text('รายสัปดาห์')),
                          DropdownMenuItem(value: 'MONTH', child: Text('รายเดือน')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(dashboardAttendanceFilterProvider.notifier).state = val;
                          }
                        },
                      );
                    }
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  // แสดง loading indicator ขนาดย่อมหรือบอกให้ผู้ใช้รอได้ แต่ที่นี่ทำให้ง่ายคือสั่งรัน
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('กำลังซิงค์ข้อมูลจากคลาวด์...'), duration: Duration(seconds: 1)),
                  );
                  await AttendanceSyncService().syncAttendanceFromCloud(force: true);
                  if (context.mounted) {
                    ref.invalidate(dashboardAttendanceProvider);
                  }
                },
                tooltip: 'รีเฟรชข้อมูล',
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildAttendanceTable(context),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)),
                  Icon(icon, color: color, size: 28),
                ],
              ),
              const SizedBox(height: 16),
              Text(value, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTable(BuildContext context) {
    final summaryAsync = ref.watch(dashboardAttendanceProvider);

    final filter = ref.watch(dashboardAttendanceFilterProvider);
    String columnLabel = filter == 'DAY' ? 'วันนี้' : (filter == 'WEEK' ? 'สัปดาห์นี้' : 'เดือนนี้');

    return summaryAsync.when(
      data: (summaries) {
        if (summaries.isEmpty) {
          return const Center(child: Text('ไม่มีข้อมูลพนักงาน'));
        }
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: [
                  const DataColumn(label: Text('ชื่อพนักงาน', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('เข้างานวันนี้', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('ออกงานวันนี้', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('ออกชั่วคราว', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('สถานะวันนี้', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('มาทำงาน ($columnLabel)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ลางาน ($columnLabel)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: summaries.map((s) {
                  final timeFormat = DateFormat('HH:mm');
                  final inTime = s.todayIn != null ? timeFormat.format(s.todayIn!) : '-';
                  final outTime = s.todayOut != null ? timeFormat.format(s.todayOut!) : '-';
                  
                  String status = 'ขาด / ยังไม่เข้า';
                  Color statusColor = Colors.grey;
                  if (s.todayIn != null && s.todayOut == null) {
                    status = 'กำลังทำงาน';
                    statusColor = Colors.green;
                  } else if (s.todayIn != null && s.todayOut != null) {
                    status = 'ออกงานแล้ว';
                    statusColor = Colors.blue;
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text(s.employeeName)),
                      DataCell(Text(inTime, style: TextStyle(color: s.todayIn != null ? Colors.black : Colors.grey))),
                      DataCell(Text(outTime, style: TextStyle(color: s.todayOut != null ? Colors.black : Colors.grey))),
                      // คอลัมน์ออกชั่วคราว
                      DataCell(_buildTempLeaveCell(s)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                        ),
                      ),
                      DataCell(Text('${s.totalPresent.toStringAsFixed(1)} วัน')),
                      DataCell(Text('${s.totalLeave} วัน', style: TextStyle(color: s.totalLeave > 0 ? Colors.orange : Colors.black))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
    );
  }

  /// Cell สรุปเวลาออกชั่วคราว
  Widget _buildTempLeaveCell(DashboardAttendanceSummary s) {
    final timeFormat = DateFormat('HH:mm');

    // กำลังออกชั่วคราวอยู่ (temp_out มี แต่ back_to_work ยังไม่มี)
    if (s.todayTempOut != null && s.todayBackToWork == null) {
      final elapsed = DateTime.now().difference(s.todayTempOut!).inMinutes;
      return Tooltip(
        message: 'ออกเมื่อ ${timeFormat.format(s.todayTempOut!)} • ยังไม่กลับ',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_run, size: 12, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '⏱ $elapsed นาที...',
                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // กลับแล้ว แสดงรวมนาที + tooltip เวลาออก-กลับ
    if (s.todayTempOut != null && s.todayBackToWork != null) {
      return Tooltip(
        message: 'ออก ${timeFormat.format(s.todayTempOut!)} → กลับ ${timeFormat.format(s.todayBackToWork!)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 12, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${s.tempLeaveMinutes} นาที',
                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    // ไม่เคยออกชั่วคราว
    return const Text('-', style: TextStyle(color: Colors.grey));
  }
}
