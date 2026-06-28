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
import '../utils/hr_status_utils.dart';
import '../widgets/hr_status_badge.dart';
import '../widgets/hr_approve_reject_dialog.dart';
import '../widgets/hr_tab_header.dart';
import '../widgets/hr_view_segmented_button.dart';

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

  Future<void> _showApproveDialog(AdvancePayment req) async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    HrApproveRejectDialog.show(
      context: context,
      title: '✅ อนุมัติเบิกล่วงหน้า',
      content: 'ต้องการอนุมัติให้ ${req.employeeName ?? 'พนักงาน'} เบิกเงินจำนวน ฿${NumberFormat('#,##0.00').format(req.amount)} หรือไม่?',
      actionLabel: 'ยืนยันอนุมัติ',
      actionColor: Colors.green,
      onConfirm: (remark) async {
        await ref.read(advanceProvider.notifier).approve(req.id, authState.currentUser!.id);
        if (mounted) SnackbarUtils.showLeft(context, 'อนุมัติเบิกล่วงหน้าสำเร็จ');
      },
    );
  }

  Future<void> _showRejectDialog(AdvancePayment req) async {
    HrApproveRejectDialog.show(
      context: context,
      title: '❌ ปฏิเสธเบิกล่วงหน้า',
      content: 'ต้องการปฏิเสธคำขอเบิกเงินของ ${req.employeeName ?? 'พนักงาน'} หรือไม่?',
      actionLabel: 'ยืนยันปฏิเสธ',
      actionColor: Colors.red,
      onConfirm: (remark) async {
        await ref.read(advanceProvider.notifier).reject(req.id);
        if (mounted) SnackbarUtils.showLeft(context, 'ปฏิเสธรายการสำเร็จ');
      },
    );
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
          HrTabHeader(
            title: title,
            onRefresh: () async {
              SnackbarUtils.showLeft(context, 'กำลังซิงค์ข้อมูลเบิกเงินล่วงหน้าจากคลาวด์...');
              await AdvanceSyncService().syncAdvanceRequestsFromCloud();
              if (context.mounted) {
                ref.read(advanceProvider.notifier).loadPending();
                ref.read(advanceProvider.notifier).loadAllHistory();
              }
            },
            onCreate: () {
              showDialog(
                context: context,
                builder: (context) => const AdvanceFormDialog(),
              );
            },
            createLabel: 'สร้างคำขอเบิกเงิน',
            createIcon: Icons.money,
          ),
          const SizedBox(height: 16),
          HrViewSegmentedButton(
            selectedView: _selectedView,
            onSelectionChanged: (value) {
              setState(() {
                _selectedView = value;
              });
            },
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
                                backgroundColor: HrStatusUtils.getStatusColor(req.status).withValues(alpha: 0.1),
                                child: Icon(
                                  req.status == 'APPROVED' || req.status == 'DEDUCTED' ? Icons.check_circle : req.status == 'REJECTED' ? Icons.cancel : Icons.money,
                                  color: HrStatusUtils.getStatusColor(req.status),
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
