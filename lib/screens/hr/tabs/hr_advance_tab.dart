import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/advance_payment.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/advance_provider.dart';
import '../widgets/advance/advance_form_dialog.dart';
import '../widgets/advance/advance_detail_dialog.dart';
import '../../../services/hr/advance_sync_service.dart';
import '../widgets/shared/hr_approve_reject_dialog.dart';
import '../widgets/shared/hr_tab_header.dart';
import '../widgets/shared/hr_view_segmented_button.dart';
import '../widgets/shared/hr_empty_state.dart';
import '../widgets/advance/advance_request_tile.dart';

class HrAdvanceTab extends ConsumerStatefulWidget {
  const HrAdvanceTab({super.key});

  @override
  ConsumerState<HrAdvanceTab> createState() => _HrAdvanceTabState();
}

class _HrAdvanceTabState extends ConsumerState<HrAdvanceTab> {
  String _selectedView = 'PENDING';

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
    final title = _selectedView == 'PENDING' ? 'รายการเบิกเงินล่วงหน้าที่รออนุมัติ' : 'ประวัติการเบิกเงินล่วงหน้าทั้งหมด';
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
            onCreate: () => showDialog(context: context, builder: (context) => const AdvanceFormDialog()),
            createLabel: 'สร้างคำขอเบิกเงิน',
            createIcon: Icons.money,
          ),
          const SizedBox(height: 16),
          HrViewSegmentedButton(
            selectedView: _selectedView,
            onSelectionChanged: (value) => setState(() => _selectedView = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? HrEmptyState(
                        icon: Icons.money_off,
                        message: _selectedView == 'PENDING' ? 'ไม่มีคำขอที่รอการอนุมัติ' : 'ไม่มีประวัติการเบิกเงิน',
                      )
                    : Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          // ✅ Using extracted AdvanceRequestTile widget
                          itemBuilder: (context, index) => AdvanceRequestTile(
                            req: list[index],
                            onTap: (req) => showDialog(
                              context: context,
                              builder: (context) => AdvanceDetailDialog(request: req),
                            ),
                            onApprove: _showApproveDialog,
                            onReject: _showRejectDialog,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
