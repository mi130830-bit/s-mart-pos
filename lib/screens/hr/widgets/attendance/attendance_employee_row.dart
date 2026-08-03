import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/attendance_provider.dart';
import '../../../../models/hr/employee_profile.dart';
import '../../../../models/hr/attendance_log.dart';
import '../../../../services/alert_service.dart';
import '../shared/hr_confirm_dialog.dart';
import 'override_clockin_dialog.dart';
import 'temp_leave_timeline.dart';
import 'realtime_duration_text.dart';

/// Employee row widget for the Attendance tab.
/// Extracted from _HrAttendanceTabState._buildEmployeeRow (124 lines).
class AttendanceEmployeeRow extends ConsumerWidget {
  final EmployeeProfile emp;
  final AttendanceLog? log;
  final bool isOnTempLeave;

  const AttendanceEmployeeRow({
    super.key,
    required this.emp,
    required this.log,
    required this.isOnTempLeave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String status = 'ยังไม่เข้างาน';
    IconData icon = Icons.person_off;
    Color color = Colors.grey;

    final attendanceState = ref.read(attendanceProvider);
    final todayLeave = attendanceState.todayApprovedLeaves
        .where((l) => l.employeeId == emp.id)
        .firstOrNull;

    Widget statusWidget;

    if (log != null) {
      if (log!.clockOut != null) {
        statusWidget = Text('เลิกงานแล้ว (${DateFormat('HH:mm').format(log!.clockOut!)})', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold));
        icon = Icons.check_circle_outline;
        color = Colors.blueGrey;
      } else if (isOnTempLeave) {
        final activeOut = log!.latestTempOutTime!;
        final roundNum = log!.activeTempLeaveRound!;
        final roundSuffix = roundNum > 1 ? ' (รอบ $roundNum)' : '';
        statusWidget = RealtimeDurationText(
          startTime: activeOut,
          prefix: 'ออกชั่วคราว$roundSuffix • ออกไป',
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        );
        icon = Icons.pause_circle_filled;
        color = Colors.orange;
      } else {
        statusWidget = Text('เข้างาน (${DateFormat('HH:mm').format(log!.clockIn!)})', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
        icon = Icons.check_circle;
        color = Colors.green;
      }
    } else if (todayLeave != null) {
      final leaveLabel = switch (todayLeave.leaveType) {
        'PERSONAL' => 'ลากิจ',
        'SICK' => 'ลาป่วย',
        'VACATION' => 'ลาพักร้อน',
        'MATERNITY' => 'ลาคลอด',
        _ => 'อื่นๆ',
      };
      statusWidget = Text('วันนี้ลา ($leaveLabel)', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold));
      icon = Icons.beach_access;
      color = Colors.teal;
    } else {
      statusWidget = Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold));
    }

    final hasTempHistory = log != null && log!.completedTempLeaveRounds > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          title: Text(emp.displayName ?? 'ไม่ระบุชื่อ'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statusWidget,
              if (todayLeave != null && todayLeave.reason != null && todayLeave.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'หมายเหตุ: ${todayLeave.reason}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              if (isOnTempLeave && log != null)
                TempLeaveTimeline(log: log!, isOnTempLeave: true),
            ],
          ),
          isThreeLine: isOnTempLeave || hasTempHistory,
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'จัดการลงเวลาให้',
            onSelected: (actionType) async {
              if (actionType == 'DELETE_TODAY') {
                final confirm = await HrConfirmDialog.show(
                  context,
                  title: 'ล้างข้อมูลการลงเวลาวันนี้',
                  content: 'คุณต้องการล้างข้อมูลการเข้า-ออกงานวันนี้ของ "${emp.displayName}" ใช่หรือไม่?\n(ใช้ในการทดสอบระบบเพื่อให้สามารถทดสอบสแกนนิ้วใหม่ได้)',
                  actionLabel: 'ล้างข้อมูล',
                  actionColor: Colors.red,
                  actionIcon: Icons.delete,
                );
                if (confirm && context.mounted) {
                  try {
                    await ref.read(attendanceProvider.notifier).deleteTodayLog(emp);
                    if (context.mounted) {
                      AlertService.show(context: context, message: 'ล้างข้อมูลของ ${emp.displayName} เรียบร้อยแล้วครับ 🟢', type: 'success');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e ❌', type: 'error');
                    }
                  }
                }
              } else {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => OverrideClockinDialog(employee: emp, actionType: actionType),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              if (log == null)
                const PopupMenuItem(value: 'IN', child: Text('เข้างาน')),
              if (log != null && log!.clockOut == null && !isOnTempLeave && log!.canStartNewTempLeave)
                const PopupMenuItem(value: 'OUT', child: Text('ออกงาน')),
              if (log != null && log!.clockOut == null && !isOnTempLeave && log!.canStartNewTempLeave)
                const PopupMenuItem(value: 'TEMP_LEAVE', child: Text('ออกชั่วคราว')),
              if (isOnTempLeave)
                const PopupMenuItem(value: 'TEMP_RETURN', child: Text('กลับเข้างาน')),
              if (log != null)
                const PopupMenuItem(
                  value: 'DELETE_TODAY',
                  child: Text('ล้างข้อมูลวันนี้ (ใช้ทดสอบ)', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        if (hasTempHistory)
          TempLeaveTimeline(log: log!, isOnTempLeave: false),
      ],
    );
  }
}
