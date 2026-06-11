import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/advance_payment.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/advance_provider.dart';
import '../widgets/advance_form_dialog.dart';
import '../widgets/advance_detail_dialog.dart';
import '../../../services/hr/advance_sync_service.dart';

class HrAdvanceTab extends ConsumerStatefulWidget {
  const HrAdvanceTab({super.key});

  @override
  ConsumerState<HrAdvanceTab> createState() => _HrAdvanceTabState();
}

class _HrAdvanceTabState extends ConsumerState<HrAdvanceTab> {
  String _selectedView = 'PENDING'; // 'PENDING' or 'ALL'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(advanceProvider.notifier).loadPending();
      ref.read(advanceProvider.notifier).loadAllHistory();
    });
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

  Future<void> _showApproveDialog(AdvancePayment req) async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ อนุมัติเบิกล่วงหน้า'),
        content: Text('ต้องการอนุมัติให้ ${req.employeeName ?? 'พนักงาน'} เบิกเงินจำนวน ฿${NumberFormat('#,##0.00').format(req.amount)} หรือไม่?'),
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

    if (confirm == true) {
      try {
        await ref.read(advanceProvider.notifier).approve(req.id, authState.currentUser!.id);
        if (mounted) {
          SnackbarUtils.showLeft(context, 'อนุมัติเบิกล่วงหน้าสำเร็จ');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
        }
      }
    }
  }

  Future<void> _showRejectDialog(AdvancePayment req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ ปฏิเสธเบิกล่วงหน้า'),
        content: Text('ต้องการปฏิเสธคำขอเบิกเงินของ ${req.employeeName ?? 'พนักงาน'} หรือไม่?'),
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

    if (confirm == true) {
      try {
        await ref.read(advanceProvider.notifier).reject(req.id);
        if (mounted) {
          SnackbarUtils.showLeft(context, 'ปฏิเสธรายการสำเร็จ');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(advanceProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    final title = _selectedView == 'PENDING'
        ? 'รายการเบิกเงินล่วงหน้าที่รออนุมัติ'
        : 'ประวัติการเบิกเงินล่วงหน้าทั้งหมด';

    final list = _selectedView == 'PENDING' ? state.pending : state.history;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      SnackbarUtils.showLeft(context, 'กำลังซิงค์ข้อมูลเบิกเงินล่วงหน้าจากคลาวด์...');
                      await AdvanceSyncService().syncAdvanceRequestsFromCloud();
                      if (context.mounted) {
                        ref.read(advanceProvider.notifier).loadPending();
                        ref.read(advanceProvider.notifier).loadAllHistory();
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('รีเฟรช'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const AdvanceFormDialog(),
                      );
                    },
                    icon: const Icon(Icons.money),
                    label: const Text('สร้างคำขอเบิกเงิน'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'PENDING',
                  icon: Icon(Icons.pending_actions),
                  label: Text('รออนุมัติ'),
                ),
                ButtonSegment(
                  value: 'ALL',
                  icon: Icon(Icons.history),
                  label: Text('ประวัติทั้งหมด'),
                ),
              ],
              selected: {_selectedView},
              onSelectionChanged: (value) {
                setState(() {
                  _selectedView = value.first;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text(
                          _selectedView == 'PENDING'
                              ? 'ไม่มีคำขอที่รอการอนุมัติ'
                              : 'ไม่มีประวัติการเบิกเงิน',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final req = list[index];
                            return ListTile(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AdvanceDetailDialog(request: req),
                                );
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                child: const Icon(Icons.account_balance_wallet, color: Colors.orange),
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
                                      color: _getStatusColor(req.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatStatus(req.status),
                                      style: TextStyle(color: _getStatusColor(req.status), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
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
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          tooltip: 'อนุมัติ',
                                          onPressed: () => _showApproveDialog(req),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                          tooltip: 'ปฏิเสธ',
                                          onPressed: () => _showRejectDialog(req),
                                        ),
                                      ],
                                    )
                                  : const Icon(Icons.chevron_right, color: Colors.grey),
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
