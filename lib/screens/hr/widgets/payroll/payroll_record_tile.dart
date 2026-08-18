import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/payroll_provider.dart';
import '../../../../utils/snackbar_utils.dart';
import '../shared/hr_confirm_dialog.dart';
import '../../utils/hr_status_utils.dart';
import 'payroll_detail_dialog.dart';

/// Record tile for the current payroll view.
/// Extracted from PayrollCurrentView itemBuilder.
class PayrollRecordTile extends ConsumerWidget {
  final dynamic req; // PayrollRecord
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  const PayrollRecordTile({
    super.key,
    required this.req,
    required this.dateFormat,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = HrStatusUtils.getStatusColor(req.status);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        child: Icon(Icons.person, color: statusColor),
      ),
      title: Row(
        children: [
          Text(
            req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              HrStatusUtils.formatStatus(req.status, HrItemType.payroll),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Text('รับ: ฿${currencyFormat.format(req.grossPay)}',
                  style: const TextStyle(color: Colors.green)),
              const SizedBox(width: 16),
              Text('หัก: ฿${currencyFormat.format(req.totalDeductions)}',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(width: 16),
              Text('สุทธิ: ฿${currencyFormat.format(req.netPay)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          Text(
              'รอบจ่าย: ${req.payCycle} | ทำงาน: ${req.workDays} วัน | ลา: ${req.leaveDays} วัน'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (req.status == 'DRAFT')
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () async {
                final confirm = await HrConfirmDialog.show(
                  context,
                  title: 'ยืนยันการลบฉบับร่าง',
                  content:
                      'ต้องการลบรายการเงินเดือนฉบับร่างนี้ใช่หรือไม่?\n\nรายการที่ยืนยันแล้วหรือจ่ายแล้วจะลบไม่ได้ เพื่อคงหลักฐานการหักเงินเบิกล่วงหน้าไว้ครบถ้วน',
                  actionLabel: 'ลบรายการ',
                  actionColor: Colors.red,
                  actionIcon: Icons.delete,
                );
                if (confirm) {
                  if (!context.mounted) return;
                  try {
                    await ref
                        .read(payrollProvider.notifier)
                        .deleteRecord(req.id);
                    if (context.mounted) {
                      SnackbarUtils.showLeft(context, 'ลบรายการสำเร็จ');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e',
                          isError: true);
                    }
                  }
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => PayrollDetailDialog(record: req),
            ),
          ),
        ],
      ),
      onTap: () => showDialog(
        context: context,
        builder: (context) => PayrollDetailDialog(record: req),
      ),
    );
  }
}
