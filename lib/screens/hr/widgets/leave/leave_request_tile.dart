import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../models/hr/leave_request.dart';
import '../shared/hr_status_badge.dart';
import '../shared/hr_approve_reject_buttons.dart';
import '../../utils/hr_status_utils.dart';

/// List tile widget for a single leave request.
/// Extracted from HrLeaveTab itemBuilder.
class LeaveRequestTile extends ConsumerWidget {
  final LeaveRequest req;
  final void Function(LeaveRequest) onApprove;
  final void Function(LeaveRequest) onReject;

  const LeaveRequestTile({
    super.key,
    required this.req,
    required this.onApprove,
    required this.onReject,
  });

  static String _formatLeaveType(String type) {
    return switch (type) {
      'PERSONAL' => 'ลากิจ',
      'SICK' => 'ลาป่วย',
      'VACATION' => 'ลาพักร้อน',
      'MATERNITY' => 'ลาคลอด',
      _ => 'อื่นๆ',
    };
  }

  static String _formatLeaveFormat(String format) {
    return switch (format) {
      'FULL_DAY' => 'เต็มวัน',
      'HALF_MORNING' => 'ครึ่งวันเช้า',
      'HALF_AFTERNOON' => 'ครึ่งวันบ่าย',
      'HOURLY' => 'ระบุเวลา',
      _ => format,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy');
    final statusColor = HrStatusUtils.getStatusColor(req.status);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        child: Icon(
          req.status == 'APPROVED'
              ? Icons.check_circle
              : req.status == 'REJECTED'
                  ? Icons.cancel
                  : Icons.description,
          color: statusColor,
        ),
      ),
      title: Row(
        children: [
          Text(
            req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          HrStatusBadge(status: req.status, type: HrItemType.leave),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${_formatLeaveType(req.leaveType)} (${_formatLeaveFormat(req.leaveFormat)}) - ${req.totalDays} วัน'),
          if (req.leaveFormat == 'HOURLY')
            Text('เวลา: ${dateFormat.format(req.startDate)} - ${dateFormat.format(req.endDate)}')
          else
            Text('วันที่: ${dateOnlyFormat.format(req.startDate)} - ${dateOnlyFormat.format(req.endDate)}'),
          if (req.reason != null && req.reason!.isNotEmpty)
            Text('เหตุผล: ${req.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
          if (req.status == 'REJECTED' && req.rejectReason != null && req.rejectReason!.isNotEmpty)
            Text('เหตุผลที่ปฏิเสธ: ${req.rejectReason}',
                style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
          Text(
            'ยื่นเมื่อ: ${dateFormat.format(req.createdAt ?? DateTime.now())}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      trailing: req.status == 'PENDING'
          ? HrApproveRejectButtons(
              onApprove: () => onApprove(req),
              onReject: () => onReject(req),
            )
          : null,
    );
  }
}
