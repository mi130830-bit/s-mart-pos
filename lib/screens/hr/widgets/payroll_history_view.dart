import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/payroll_provider.dart';
import '../../../../state/hr/employee_provider.dart';
import '../../../../repositories/expense_repository.dart';
import '../../../../utils/snackbar_utils.dart';
import 'payroll_detail_dialog.dart';

class PayrollHistoryView extends ConsumerStatefulWidget {
  final PayrollState state;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final DateTime historyStart;
  final DateTime historyEnd;
  final int? historyEmployeeFilter;
  final VoidCallback onSelectHistoryRange;
  final void Function(int days) onSelectQuickRange;
  final void Function(int? val) onEmployeeFilterChanged;
  final VoidCallback onLoadHistory;

  const PayrollHistoryView({
    super.key,
    required this.state,
    required this.dateFormat,
    required this.currencyFormat,
    required this.historyStart,
    required this.historyEnd,
    required this.historyEmployeeFilter,
    required this.onSelectHistoryRange,
    required this.onSelectQuickRange,
    required this.onEmployeeFilterChanged,
    required this.onLoadHistory,
  });

  @override
  ConsumerState<PayrollHistoryView> createState() => _PayrollHistoryViewState();
}

class _PayrollHistoryViewState extends ConsumerState<PayrollHistoryView> {
  String? _expandedPeriodKey;

  Widget _buildQuickRangeChip(String label, int days) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => widget.onSelectQuickRange(days),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeeProvider).employees;

    return Expanded(
      child: Column(
        children: [
          // ── Filter bar ──────────────────────────────────────────────
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onSelectHistoryRange,
                icon: const Icon(Icons.calendar_month),
                label: Text('${widget.dateFormat.format(widget.historyStart)} - ${widget.dateFormat.format(widget.historyEnd)}'),
              ),
              const SizedBox(width: 8),
              // Quick select buttons
              _buildQuickRangeChip('สัปดาห์นี้', 7),
              const SizedBox(width: 4),
              _buildQuickRangeChip('เดือนนี้', 30),
              const SizedBox(width: 4),
              _buildQuickRangeChip('3 เดือน', 90),
              const SizedBox(width: 12),
              // Employee filter dropdown
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  initialValue: widget.historyEmployeeFilter,
                  decoration: const InputDecoration(
                    labelText: 'พนักงาน',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
                    ...employees.map((e) => DropdownMenuItem<int?>(
                      value: e.id,
                      child: Text(e.displayName ?? 'ID: ${e.id}', overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: widget.onEmployeeFilterChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Period summaries list ───────────────────────────────────
          Expanded(
            child: widget.state.isLoading && widget.state.periodSummaries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : widget.state.periodSummaries.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('ยังไม่มีประวัติการจ่ายเงินในช่วงเวลาที่เลือก', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListView.builder(
                          itemCount: widget.state.periodSummaries.length,
                          itemBuilder: (context, index) {
                            final summary = widget.state.periodSummaries[index];
                            final periodStart = DateTime.tryParse(summary['period_start']?.toString() ?? '') ?? DateTime.now();
                            final periodEnd = DateTime.tryParse(summary['period_end']?.toString() ?? '') ?? DateTime.now();
                            final employeeCount = int.tryParse(summary['employee_count']?.toString() ?? '0') ?? 0;
                            final totalNet = double.tryParse(summary['total_net']?.toString() ?? '0') ?? 0.0;
                            final totalGross = double.tryParse(summary['total_gross']?.toString() ?? '0') ?? 0.0;
                            final totalDed = double.tryParse(summary['total_deductions']?.toString() ?? '0') ?? 0.0;
                            final periodKey = '${periodStart.toIso8601String()}_${periodEnd.toIso8601String()}';
                            final isExpanded = _expandedPeriodKey == periodKey;

                            // Get matching detail records for this period
                            final periodRecords = widget.state.historyRecords.where((r) =>
                              r.periodStart.year == periodStart.year &&
                              r.periodStart.month == periodStart.month &&
                              r.periodStart.day == periodStart.day &&
                              r.periodEnd.year == periodEnd.year &&
                              r.periodEnd.month == periodEnd.month &&
                              r.periodEnd.day == periodEnd.day
                            ).toList();

                            return Column(
                              children: [
                                if (index > 0) const Divider(height: 1),
                                // ── Period summary row ─────────────────────
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
                                        Text('รับ: ฿${widget.currencyFormat.format(totalGross)}', style: const TextStyle(color: Colors.green, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Text('หัก: ฿${widget.currencyFormat.format(totalDed)}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Text('สุทธิ: ฿${widget.currencyFormat.format(totalNet)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
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
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('ยืนยันล้างประวัติทั้งรอบ'),
                                              content: Text('ต้องการลบประวัติเงินเดือนรอบ ${widget.dateFormat.format(periodStart)} - ${widget.dateFormat.format(periodEnd)} ทั้งหมดใช่หรือไม่?\n\n* ยอดเงินเบิกของทุกคนในรอบนี้จะถูกคืนกลับให้อัตโนมัติ (สำหรับใช้ทดสอบ)\n* ระบบจะลบประวัติรายการที่เคยลงบันทึกใน "บัญชีรายจ่าย" ให้อัตโนมัติด้วย'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(context, true), 
                                                  child: const Text('ล้างประวัติ')
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            if (!context.mounted) return;
                                            try {
                                              // Delete all records in this period, which will also revert their advances
                                              for (var rec in periodRecords) {
                                                await ref.read(payrollProvider.notifier).deleteRecord(rec.id);
                                              }
                                              // Also delete linked expense
                                              try {
                                                final title = 'จ่ายเงินเดือนรอบ ${widget.dateFormat.format(periodStart)} - ${widget.dateFormat.format(periodEnd)}';
                                                await ExpenseRepository().deleteExpenseByTitle(title);
                                              } catch (e) {
                                                debugPrint('Failed to delete linked expense: $e');
                                              }
                                              widget.onLoadHistory();
                                              if (context.mounted) {
                                                SnackbarUtils.showLeft(context, 'ล้างประวัติสำเร็จ');
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
                                              }
                                            }
                                          }
                                        },
                                      ),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _expandedPeriodKey = isExpanded ? null : periodKey;
                                    });
                                  },
                                ),
                                // ── Expanded detail (per employee) ────────
                                if (isExpanded)
                                  Container(
                                    color: Colors.grey.withValues(alpha: 0.04),
                                    child: Column(
                                      children: [
                                        const Divider(height: 1),
                                        if (periodRecords.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text('ไม่พบรายละเอียดรายคน', style: TextStyle(color: Colors.grey)),
                                          )
                                        else
                                          ...periodRecords.map((rec) => ListTile(
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
                                                      '฿${widget.currencyFormat.format(rec.netPay)}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
                                                    ),
                                                    if (rec.totalDeductions > 0)
                                                      Text(
                                                        'หัก ฿${widget.currencyFormat.format(rec.totalDeductions)}',
                                                        style: const TextStyle(color: Colors.red, fontSize: 11),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                  tooltip: 'ลบรายการนี้ (ใช้ทดสอบ)',
                                                  onPressed: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text('ยืนยันการลบและคืนค่ายอดเบิก'),
                                                        content: const Text('ต้องการลบรายการประวัติเงินเดือนนี้ใช่หรือไม่?\n\n*ระบบจะทำการคืนยอดเงินเบิกกลับให้อัตโนมัติ เพื่อให้สามารถนำมาหักใหม่ได้ (สำหรับใช้ทดสอบ)'),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                            onPressed: () => Navigator.pop(context, true), 
                                                            child: const Text('ลบรายการ')
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      if (!context.mounted) return;
                                                      try {
                                                        await ref.read(payrollProvider.notifier).deleteRecord(rec.id);
                                                        widget.onLoadHistory();
                                                        if (context.mounted) {
                                                          SnackbarUtils.showLeft(context, 'ลบรายการสำเร็จ');
                                                        }
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                                                  tooltip: 'ดูรายละเอียด',
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => PayrollDetailDialog(record: rec),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => PayrollDetailDialog(record: rec),
                                              );
                                            },
                                          )),
                                        // ── Summary footer ────────────────────
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
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
