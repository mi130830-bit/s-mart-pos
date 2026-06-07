import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/payroll_record.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/payroll_provider.dart';

class PayrollDetailDialog extends ConsumerStatefulWidget {
  final PayrollRecord record;

  const PayrollDetailDialog({super.key, required this.record});

  @override
  ConsumerState<PayrollDetailDialog> createState() => _PayrollDetailDialogState();
}

class _PayrollDetailDialogState extends ConsumerState<PayrollDetailDialog> {
  Future<void> _confirmPayroll() async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    try {
      await ref.read(payrollProvider.notifier).confirm(widget.record.id, authState.currentUser!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยืนยันรายการสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _markPaid() async {
    try {
      await ref.read(payrollProvider.notifier).markPaid(widget.record.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกการจ่ายเงินสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isDeduction = false}) {
    final currencyFormat = NumberFormat('#,##0.00');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
          Text(
            '${isDeduction ? '-' : ''}฿${currencyFormat.format(amount)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isDeduction ? Colors.red : (isTotal ? Colors.blue : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final r = widget.record;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('รายละเอียดสลิปเงินเดือน'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ชื่อพนักงาน: ${r.employeeName ?? 'พนักงาน (ID: ${r.employeeId})'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text('รอบจ่าย: ${r.payCycle} (${dateFormat.format(r.periodStart)} - ${dateFormat.format(r.periodEnd)})'),
              Text('สถานะ: ${r.status == 'DRAFT' ? 'ฉบับร่าง' : r.status == 'CONFIRMED' ? 'ยืนยันแล้ว' : 'จ่ายแล้ว'}'),
              const Divider(height: 32),
              
              const Text('สถิติการทำงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('จำนวนวันทำงาน: ${r.workDays} วัน'),
                  Text('จำนวนวันลา: ${r.leaveDays} วัน'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('จำนวนวันขาด: ${r.absentDays} วัน'),
                  Text('จำนวนครั้งที่มาสาย: ${r.lateCount} ครั้ง'),
                ],
              ),
              if (r.tripCount > 0)
                Text('จำนวนเที่ยววิ่งรถ: ${r.tripCount} เที่ยว'),
              
              const Divider(height: 32),
              
              const Text('รายได้ (Income)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const SizedBox(height: 8),
              if (r.baseSalary > 0) _buildSummaryRow('เงินเดือนพื้นฐาน', r.baseSalary),
              if (r.dailyWageTotal > 0) _buildSummaryRow('ค่าแรงรายวัน (${r.workDays + r.leaveDays} วัน)', r.dailyWageTotal),
              if (r.tripTotalFee > 0) _buildSummaryRow('ค่าเที่ยว', r.tripTotalFee),
              if (r.overtimePay > 0) _buildSummaryRow('ค่าล่วงเวลา (OT)', r.overtimePay),
              if (r.bonus > 0) _buildSummaryRow('โบนัส/เบี้ยเลี้ยง', r.bonus),
              const Divider(),
              _buildSummaryRow('รวมรายได้', r.grossPay, isTotal: true),
              
              const SizedBox(height: 24),
              
              const Text('รายการหัก (Deductions)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
              const SizedBox(height: 8),
              if (r.advanceDeductions > 0) _buildSummaryRow('เบิกล่วงหน้า', r.advanceDeductions, isDeduction: true),
              if (r.socialSecurity > 0) _buildSummaryRow('ประกันสังคม', r.socialSecurity, isDeduction: true),
              if (r.otherDeductions > 0) _buildSummaryRow('หักอื่นๆ', r.otherDeductions, isDeduction: true),
              const Divider(),
              _buildSummaryRow('รวมรายการหัก', r.totalDeductions, isTotal: true, isDeduction: true),
              
              const Divider(height: 32, thickness: 2),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildSummaryRow('ยอดสุทธิที่ต้องจ่าย (Net Pay)', r.netPay, isTotal: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        if (r.status == 'DRAFT')
          ElevatedButton(
            onPressed: _confirmPayroll,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('ยืนยันยอดนี้'),
          ),
        if (r.status == 'CONFIRMED')
          ElevatedButton(
            onPressed: _markPaid,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('มาร์คว่าจ่ายแล้ว'),
          ),
      ],
    );
  }
}
