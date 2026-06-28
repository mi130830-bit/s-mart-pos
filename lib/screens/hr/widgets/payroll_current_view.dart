import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/payroll_provider.dart';
import '../utils/hr_status_utils.dart';
import '../../../../utils/snackbar_utils.dart';
import 'payroll_detail_dialog.dart';

class PayrollCurrentView extends ConsumerWidget {
  final PayrollState state;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final DateTime startDate;
  final DateTime endDate;

  const PayrollCurrentView({
    super.key,
    required this.state,
    required this.dateFormat,
    required this.currencyFormat,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.records.isEmpty) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.records.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'ยังไม่มีข้อมูลเงินเดือนในรอบ ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('กดปุ่ม "คำนวณรอบนี้" เพื่อสร้างรายการใหม่', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListView.separated(
          itemCount: state.records.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final req = state.records[index];
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
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
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
                      Text('รับ: ฿${currencyFormat.format(req.grossPay)}', style: const TextStyle(color: Colors.green)),
                      const SizedBox(width: 16),
                      Text('หัก: ฿${currencyFormat.format(req.totalDeductions)}', style: const TextStyle(color: Colors.red)),
                      const SizedBox(width: 16),
                      Text('สุทธิ: ฿${currencyFormat.format(req.netPay)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  Text('รอบจ่าย: ${req.payCycle} | ทำงาน: ${req.workDays} วัน | ลา: ${req.leaveDays} วัน'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('ยืนยันการลบและคืนค่ายอดเบิก'),
                          content: const Text('ต้องการลบรายการเงินเดือนนี้ใช่หรือไม่?\n\n*หากมีการหักยอดเงินเบิกล่วงหน้าไปแล้ว ระบบจะทำการคืนยอดเงินเบิกกลับให้อัตโนมัติ เพื่อให้สามารถนำมาหักใหม่ได้ (สำหรับใช้ทดสอบ)'),
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
                          await ref.read(payrollProvider.notifier).deleteRecord(req.id);
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
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => PayrollDetailDialog(record: req),
                      );
                    },
                  ),
                ],
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => PayrollDetailDialog(record: req),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
