import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/hr/advance_payment.dart';
import '../shared/hr_status_badge.dart';
import '../shared/hr_approve_reject_buttons.dart';
import '../../utils/hr_status_utils.dart';

/// List tile widget for a single advance payment request.
/// Extracted from HrAdvanceTab itemBuilder.
class AdvanceRequestTile extends StatelessWidget {
  final AdvancePayment req;
  final void Function(AdvancePayment) onTap;
  final void Function(AdvancePayment) onApprove;
  final void Function(AdvancePayment) onReject;

  const AdvanceRequestTile({
    super.key,
    required this.req,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');
    final statusColor = HrStatusUtils.getStatusColor(req.status);

    return ListTile(
      onTap: () => onTap(req),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        child: Icon(
          req.status == 'APPROVED' || req.status == 'DEDUCTED'
              ? Icons.check_circle
              : req.status == 'REJECTED'
                  ? Icons.cancel
                  : Icons.money,
          color: statusColor,
        ),
      ),
      title: Row(
        children: [
          Text(
            req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          HrStatusBadge(status: req.status, type: HrItemType.advance),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'ยอดเบิก: ฿${currencyFormat.format(req.amount)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          Text('วันที่ขอเบิก: ${dateFormat.format(req.requestDate)}'),
          if (req.reason != null && req.reason!.isNotEmpty)
            Text('เหตุผล: ${req.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: req.status == 'PENDING'
          ? HrApproveRejectButtons(
              onApprove: () => onApprove(req),
              onReject: () => onReject(req),
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
