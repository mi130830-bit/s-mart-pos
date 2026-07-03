import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hr/leave_request.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/leave_provider.dart';
import '../../../services/hr/leave_sync_service.dart';
import '../widgets/leave/leave_form_dialog.dart';
import '../widgets/shared/hr_approve_reject_dialog.dart';
import '../widgets/shared/hr_tab_header.dart';
import '../widgets/shared/hr_view_segmented_button.dart';
import '../widgets/shared/hr_empty_state.dart';
import '../widgets/leave/leave_request_tile.dart';

class HrLeaveTab extends ConsumerStatefulWidget {
  const HrLeaveTab({super.key});

  @override
  ConsumerState<HrLeaveTab> createState() => _HrLeaveTabState();
}

class _HrLeaveTabState extends ConsumerState<HrLeaveTab> {
  String _selectedView = 'PENDING';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leaveProvider.notifier).loadPending();
      ref.read(leaveProvider.notifier).loadAllHistory();
    });
  }

  Future<void> _showApproveDialog(LeaveRequest req) async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    HrApproveRejectDialog.show(
      context: context,
      title: '✅ อนุมัติใบลา',
      content: 'ต้องการอนุมัติการลางานของ ${req.employeeName ?? 'พนักงาน'} หรือไม่?',
      actionLabel: 'ยืนยันอนุมัติ',
      actionColor: Colors.green,
      onConfirm: (remark) async {
        await ref.read(leaveProvider.notifier).approve(req.id, authState.currentUser!.id);
        if (mounted) SnackbarUtils.showLeft(context, 'อนุมัติใบลาสำเร็จ');
      },
    );
  }

  Future<void> _showRejectDialog(LeaveRequest req) async {
    HrApproveRejectDialog.show(
      context: context,
      title: '❌ ปฏิเสธใบลา',
      content: 'เหตุผลที่ปฏิเสธการลาของ ${req.employeeName ?? 'พนักงาน'}:',
      actionLabel: 'ยืนยันปฏิเสธ',
      actionColor: Colors.red,
      onConfirm: (remark) async {
        final finalRemark = remark.trim().isEmpty ? 'ไม่ระบุเหตุผล (ไม่อนุมัติ)' : '${remark.trim()} (ไม่อนุมัติ)';
        await ref.read(leaveProvider.notifier).reject(req.id, finalRemark);
        if (mounted) SnackbarUtils.showLeft(context, 'ปฏิเสธใบลาสำเร็จ');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final title = _selectedView == 'PENDING' ? 'รายการใบลาที่รออนุมัติ' : 'ประวัติการลาทั้งหมด';
    final list = _selectedView == 'PENDING' ? leaveState.pending : leaveState.history;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HrTabHeader(
            title: title,
            onRefresh: () async {
              try { await LeaveSyncService().syncLeaveRequestsFromCloud(); } catch (_) {}
              ref.read(leaveProvider.notifier).loadPending();
              ref.read(leaveProvider.notifier).loadAllHistory();
              if (context.mounted) SnackbarUtils.showLeft(context, 'ซิงค์ใบลาจากคลาวด์เรียบร้อย');
            },
            onCreate: () => showDialog(context: context, builder: (context) => const LeaveFormDialog()),
            createLabel: 'สร้างใบลา',
            createIcon: Icons.add,
          ),
          const SizedBox(height: 16),
          HrViewSegmentedButton(
            selectedView: _selectedView,
            onSelectionChanged: (value) => setState(() => _selectedView = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: leaveState.isLoading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? HrEmptyState(
                        icon: Icons.event_note,
                        message: _selectedView == 'PENDING' ? 'ไม่มีใบลาที่รอการอนุมัติ' : 'ไม่มีประวัติการลา',
                      )
                    : Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          // ✅ Using extracted LeaveRequestTile widget
                          itemBuilder: (context, index) => LeaveRequestTile(
                            req: list[index],
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
