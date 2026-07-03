import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/dashboard_attendance_provider.dart';
import '../../../../models/hr/dashboard_attendance_summary.dart';

/// DataTable widget showing attendance summary per employee.
/// Extracted from _HrSummaryTabState._buildAttendanceTable +
/// _buildTempLeaveCell (combined ~155 lines).
class HrAttendanceTable extends ConsumerWidget {
  const HrAttendanceTable({super.key});

  Widget _buildTempLeaveCell(DashboardAttendanceSummary s) {
    final timeFormat = DateFormat('HH:mm');

    final activeRound = s.activeTempLeaveRound;
    final activeOut = s.activeTempOutTime;
    if (activeRound != null && activeOut != null) {
      final elapsed = DateTime.now().difference(activeOut).inMinutes;
      final roundSuffix = activeRound > 1 ? ' รอบ $activeRound' : '';
      return Tooltip(
        message: 'ออกเมื่อ ${timeFormat.format(activeOut)} (รอบ$activeRound) • ยังไม่กลับ',
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
                '⏱$roundSuffix $elapsed นาที...',
                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (s.tempLeaveMinutes > 0) {
      final List<String> roundDetails = [];
      if (s.todayTempOut != null && s.todayBackToWork != null) {
        roundDetails.add('รอบ1: ${timeFormat.format(s.todayTempOut!)} → ${timeFormat.format(s.todayBackToWork!)}');
      }
      if (s.todayTempOut2 != null && s.todayBackToWork2 != null) {
        roundDetails.add('รอบ2: ${timeFormat.format(s.todayTempOut2!)} → ${timeFormat.format(s.todayBackToWork2!)}');
      }
      if (s.todayTempOut3 != null && s.todayBackToWork3 != null) {
        roundDetails.add('รอบ3: ${timeFormat.format(s.todayTempOut3!)} → ${timeFormat.format(s.todayBackToWork3!)}');
      }

      return Tooltip(
        message: roundDetails.join('\n'),
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

    return const Text('-', style: TextStyle(color: Colors.grey));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardAttendanceProvider);
    final filter = ref.watch(dashboardAttendanceFilterProvider);
    final columnLabel = filter == 'DAY' ? 'วันนี้' : (filter == 'WEEK' ? 'สัปดาห์นี้' : 'เดือนนี้');

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
                  DataColumn(label: Text('มาทำงาน ($columnLabel)', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ลางาน ($columnLabel)', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: summaries.map((s) {
                  final timeFormat = DateFormat('HH:mm');
                  final inTime = s.todayIn != null ? timeFormat.format(s.todayIn!) : '-';
                  final outTime = s.todayOut != null ? timeFormat.format(s.todayOut!) : '-';

                  String status = 'ขาด / ยังไม่เข้า';
                  Color statusColor = Colors.grey;

                  if (s.isLeaveToday) {
                    status = 'ลางาน';
                    statusColor = Colors.orange;
                  } else if (s.todayIn != null && s.todayOut == null) {
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
                      DataCell(Text('${s.totalLeave} วัน',
                          style: TextStyle(color: s.totalLeave > 0 ? Colors.orange : Colors.black))),
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
}
