import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/payroll_provider.dart';
import '../../../../repositories/expense_repository.dart';
import '../../../../utils/snackbar_utils.dart';
import '../shared/hr_confirm_dialog.dart';
import 'payroll_detail_dialog.dart';

/// Expandable tile for a single payroll period in history view.
/// Extracted from PayrollHistoryView ListView itemBuilder (~200 lines).
class PayrollPeriodSummaryTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> summary;
  final List<dynamic> periodRecords; // List<PayrollRecord>
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final VoidCallback onLoadHistory;

  const PayrollPeriodSummaryTile({
    super.key,
    required this.summary,
    required this.periodRecords,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onLoadHistory,
  });

  @override
  ConsumerState<PayrollPeriodSummaryTile> createState() => _PayrollPeriodSummaryTileState();
}

class _PayrollPeriodSummaryTileState extends ConsumerState<PayrollPeriodSummaryTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final periodStart = DateTime.tryParse(summary['period_start']?.toString() ?? '') ?? DateTime.now();
    final periodEnd = DateTime.tryParse(summary['period_end']?.toString() ?? '') ?? DateTime.now();
    final employeeCount = int.tryParse(summary['employee_count']?.toString() ?? '0') ?? 0;
    final totalNet = double.tryParse(summary['total_net']?.toString() ?? '0') ?? 0.0;
    final totalGross = double.tryParse(summary['total_gross']?.toString() ?? '0') ?? 0.0;
    final totalDed = double.tryParse(summary['total_deductions']?.toString() ?? '0') ?? 0.0;

    return Column(
      children: [
        // ── Period summary header ─────────────────────────────────────
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            child: const Icon(Icons.calendar_today, color: Colors.green),
          ),
          title: Text(
            '📅 ${widget.dateFormat.format(periodStart)} - ${widget.dateFormat.format(periodEnd)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text('👥 $employeeCount คน', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 12),
                Text('รับ: ฿${widget.currencyFormat.format(totalGross)}',
                    style: const TextStyle(color: Colors.green, fontSize: 13)),
                const SizedBox(width: 8),
                Text('หัก: ฿${widget.currencyFormat.format(totalDed)}',
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                const SizedBox(width: 8),
                Text('สุทธิ: ฿${widget.currencyFormat.format(totalNet)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: 'ล้างประวัติรอบนี้ (สำหรับทดสอบ)',
                onPressed: () async {
                  final confirm = await HrConfirmDialog.show(
                    context,
                    title: 'ยืนยันล้างประวัติทั้งรอบ',
                    content:
                        'ต้องการลบประวัติเงินเดือนรอบ ${widget.dateFormat.format(periodStart)} - ${widget.dateFormat.format(periodEnd)} ทั้งหมดใช่หรือไม่?\n\n* ยอดเงินเบิกของทุกคนในรอบนี้จะถูกคืนกลับให้อัตโนมัติ (สำหรับใช้ทดสอบ)\n* ระบบจะลบประวัติรายการที่เคยลงบันทึกใน "บัญชีรายจ่าย" ให้อัตโนมัติด้วย',
                    actionLabel: 'ล้างประวัติ',
                    actionColor: Colors.red,
                    actionIcon: Icons.delete_sweep,
                  );
                  if (confirm && context.mounted) {
                    try {
                      for (var rec in widget.periodRecords) {
                        await ref.read(payrollProvider.notifier).deleteRecord(rec.id);
                      }
                      try {
                        final title =
                            'จ่ายเงินเดือนรอบ ${widget.dateFormat.format(periodStart)} - ${widget.dateFormat.format(periodEnd)}';
                        await ExpenseRepository().deleteExpenseByTitle(title);
                      } catch (e) {
                        debugPrint('Failed to delete linked expense: $e');
                      }
                      widget.onLoadHistory();
                      if (context.mounted) SnackbarUtils.showLeft(context, 'ล้างประวัติสำเร็จ');
                    } catch (e) {
                      if (context.mounted) SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
                    }
                  }
                },
              ),
              Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            ],
          ),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
        // ── Expanded employee details ─────────────────────────────────
        if (_isExpanded)
          Container(
            color: Colors.grey.withValues(alpha: 0.04),
            child: Column(
              children: [
                const Divider(height: 1),
                if (widget.periodRecords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('ไม่พบรายละเอียดรายคน', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...widget.periodRecords.map((rec) => _EmployeeDetailTile(
                        rec: rec,
                        currencyFormat: widget.currencyFormat,
                        onLoadHistory: widget.onLoadHistory,
                      )),
                // ── Summary footer ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    border: Border(top: BorderSide(color: Colors.blue.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('💰 ยอดสุทธิรวม: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '฿${widget.currencyFormat.format(totalNet)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Per-employee detail tile inside an expanded period summary.
class _EmployeeDetailTile extends ConsumerWidget {
  final dynamic rec; // PayrollRecord
  final NumberFormat currencyFormat;
  final VoidCallback onLoadHistory;

  const _EmployeeDetailTile({
    required this.rec,
    required this.currencyFormat,
    required this.onLoadHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFE3F2FD),
        child: Icon(Icons.person, size: 18, color: Colors.blue),
      ),
      title: Text(
        rec.employeeName ?? 'ID: ${rec.employeeId}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        'ทำงาน: ${rec.workDays} วัน | ลา: ${rec.leaveDays} วัน',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${currencyFormat.format(rec.netPay)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
              ),
              if (rec.totalDeductions > 0)
                Text(
                  'หัก ฿${currencyFormat.format(rec.totalDeductions)}',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'ลบรายการนี้ (ใช้ทดสอบ)',
            onPressed: () async {
              final confirm = await HrConfirmDialog.show(
                context,
                title: 'ยืนยันการลบและคืนค่ายอดเบิก',
                content:
                    'ต้องการลบรายการประวัติเงินเดือนนี้ใช่หรือไม่?\n\n*ระบบจะทำการคืนยอดเงินเบิกกลับให้อัตโนมัติ เพื่อให้สามารถนำมาหักใหม่ได้ (สำหรับใช้ทดสอบ)',
                actionLabel: 'ลบรายการ',
                actionColor: Colors.red,
                actionIcon: Icons.delete,
              );
              if (confirm && context.mounted) {
                try {
                  await ref.read(payrollProvider.notifier).deleteRecord(rec.id);
                  onLoadHistory();
                  if (context.mounted) SnackbarUtils.showLeft(context, 'ลบรายการสำเร็จ');
                } catch (e) {
                  if (context.mounted) SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
            tooltip: 'ดูรายละเอียด',
            onPressed: () => showDialog(
              context: context,
              builder: (context) => PayrollDetailDialog(record: rec),
            ),
          ),
        ],
      ),
      onTap: () => showDialog(
        context: context,
        builder: (context) => PayrollDetailDialog(record: rec),
      ),
    );
  }
}
