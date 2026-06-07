import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/advance_payment.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/advance_provider.dart';
import '../../../repositories/hr/advance_repository.dart';

class AdvanceDetailDialog extends ConsumerStatefulWidget {
  final AdvancePayment request;

  const AdvanceDetailDialog({super.key, required this.request});

  @override
  ConsumerState<AdvanceDetailDialog> createState() => _AdvanceDetailDialogState();
}

class _AdvanceDetailDialogState extends ConsumerState<AdvanceDetailDialog> {
  final AdvanceRepository _repo = AdvanceRepository();
  late Future<List<Map<String, dynamic>>> _deductionsFuture;
  late AdvancePayment _currentRequest;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadDeductions();
  }

  void _loadDeductions() {
    _deductionsFuture = _repo.getDeductionsForAdvance(_currentRequest.id);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'PARTIAL': return Colors.orange;
      case 'DEDUCTED': return Colors.blue;
      case 'REJECTED': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'APPROVED': return 'อนุมัติ (รอหัก)';
      case 'PARTIAL': return 'หักบางส่วน';
      case 'DEDUCTED': return 'หักครบแล้ว';
      case 'REJECTED': return 'ปฏิเสธ';
      default: return 'รออนุมัติ';
    }
  }

  Future<void> _approve() async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ อนุมัติเบิกล่วงหน้า'),
        content: Text('ต้องการอนุมัติให้ ${_currentRequest.employeeName ?? 'พนักงาน'} เบิกเงินจำนวน ฿${NumberFormat('#,##0.00').format(_currentRequest.amount)} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันอนุมัติ'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(advanceProvider.notifier).approve(_currentRequest.id, authState.currentUser!.id);
        setState(() {
          _currentRequest = AdvancePayment(
            id: _currentRequest.id,
            employeeId: _currentRequest.employeeId,
            amount: _currentRequest.amount,
            requestDate: _currentRequest.requestDate,
            reason: _currentRequest.reason,
            status: 'APPROVED',
            approvedBy: authState.currentUser!.id,
            approvedAt: DateTime.now(),
            remainingAmount: _currentRequest.amount,
            installmentAmount: _currentRequest.installmentAmount,
            note: _currentRequest.note,
            createdAt: _currentRequest.createdAt,
            employeeName: _currentRequest.employeeName,
          );
          _loadDeductions();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อนุมัติเบิกล่วงหน้าสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ ปฏิเสธเบิกล่วงหน้า'),
        content: Text('ต้องการปฏิเสธคำขอเบิกเงินของ ${_currentRequest.employeeName ?? 'พนักงาน'} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันปฏิเสธ'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(advanceProvider.notifier).reject(_currentRequest.id);
        setState(() {
          _currentRequest = AdvancePayment(
            id: _currentRequest.id,
            employeeId: _currentRequest.employeeId,
            amount: _currentRequest.amount,
            requestDate: _currentRequest.requestDate,
            reason: _currentRequest.reason,
            status: 'REJECTED',
            approvedBy: _currentRequest.approvedBy,
            approvedAt: _currentRequest.approvedAt,
            remainingAmount: _currentRequest.remainingAmount,
            installmentAmount: _currentRequest.installmentAmount,
            note: _currentRequest.note,
            createdAt: _currentRequest.createdAt,
            employeeName: _currentRequest.employeeName,
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ปฏิเสธรายการสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat('#,##0.00');
    final req = _currentRequest;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('รายละเอียดการเบิกเงินล่วงหน้า'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('สถานะ: ', style: TextStyle(color: Colors.black54)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(req.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatStatus(req.status),
                      style: TextStyle(
                        color: _getStatusColor(req.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              _buildDetailRow('เลขที่รายการเบิก', '#${req.id}', isBold: true),
              _buildDetailRow(
                'ยอดเงินที่ขอเบิก',
                '฿${currencyFormat.format(req.amount)}',
                valueColor: Colors.blue,
                isBold: true,
              ),
              _buildDetailRow(
                'ยอดคงเหลือต้องหัก',
                '฿${currencyFormat.format(req.remainingAmount)}',
                valueColor: req.remainingAmount > 0 ? Colors.orange : Colors.green,
                isBold: true,
              ),
              if (req.installmentAmount != null)
                _buildDetailRow(
                  'หักชำระต่องวด',
                  '฿${currencyFormat.format(req.installmentAmount)}',
                ),
              _buildDetailRow('วันที่ยื่นคำขอ', dateFormat.format(req.requestDate)),
              if (req.reason != null && req.reason!.isNotEmpty)
                _buildDetailRow('เหตุผลที่ขอเบิก', req.reason!),
              
              const Divider(height: 24),
              
              if (req.status != 'PENDING') ...[
                const Text('ข้อมูลการอนุมัติ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                _buildDetailRow('ผู้อนุมัติ (ID)', req.approvedBy?.toString() ?? '-'),
                if (req.approvedAt != null)
                  _buildDetailRow('อนุมัติเมื่อวันที่', dateTimeFormat.format(req.approvedAt!)),
                const Divider(height: 24),
              ],

              const Text('ประวัติการหักชำระคืนจากเงินเดือน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _deductionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ));
                  }
                  if (snapshot.hasError) {
                    return Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
                  }
                  final deductions = snapshot.data ?? [];
                  if (deductions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('ยังไม่มีการหักชำระคืนในระบบ', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: deductions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = deductions[index];
                        final amt = double.tryParse(d['deducted_amount']?.toString() ?? '0') ?? 0.0;
                        final date = DateTime.tryParse(d['deducted_at']?.toString() ?? '') ?? DateTime.now();
                        final pStart = DateTime.tryParse(d['period_start']?.toString() ?? '');
                        final pEnd = DateTime.tryParse(d['period_end']?.toString() ?? '');
                        final cycle = d['pay_cycle']?.toString() ?? '';
                        
                        String periodText = '';
                        if (pStart != null && pEnd != null) {
                          periodText = ' ($cycle: ${dateFormat.format(pStart)} - ${dateFormat.format(pEnd)})';
                        }
                        
                        return ListTile(
                          dense: true,
                          title: Text('หักคืน ฿${currencyFormat.format(amt)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          subtitle: Text('วันที่หัก: ${dateTimeFormat.format(date)}\nรอบบัญชี:$periodText', style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        if (req.status == 'PENDING') ...[
          TextButton(
            onPressed: _reject,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ปฏิเสธคำขอ'),
          ),
          ElevatedButton(
            onPressed: _approve,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('อนุมัติ'),
          ),
        ]
      ],
    );
  }
}
