import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/leave_request.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/leave_provider.dart';
import '../../../services/hr/leave_sync_service.dart';
import '../widgets/leave_form_dialog.dart';
import '../utils/hr_status_utils.dart';
import '../widgets/hr_status_badge.dart';
import '../widgets/hr_approve_reject_dialog.dart';
import '../widgets/hr_tab_header.dart';
import '../widgets/hr_view_segmented_button.dart';

class HrLeaveTab extends ConsumerStatefulWidget {
  const HrLeaveTab({super.key});

  @override
  ConsumerState<HrLeaveTab> createState() => _HrLeaveTabState();
}

class _HrLeaveTabState extends ConsumerState<HrLeaveTab> {
  String _selectedView = 'PENDING'; // 'PENDING' or 'ALL'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leaveProvider.notifier).loadPending();
      ref.read(leaveProvider.notifier).loadAllHistory();
    });
  }

  String _formatLeaveType(String type) {
    switch (type) {
      case 'PERSONAL': return 'ลากิจ';
      case 'SICK': return 'ลาป่วย';
      case 'VACATION': return 'ลาพักร้อน';
      case 'MATERNITY': return 'ลาคลอด';
      default: return 'อื่นๆ';
    }
  }

  String _formatLeaveFormat(String format) {
    switch (format) {
      case 'FULL_DAY': return 'เต็มวัน';
      case 'HALF_MORNING': return 'ครึ่งวันเช้า';
      case 'HALF_AFTERNOON': return 'ครึ่งวันบ่าย';
      case 'HOURLY': return 'ระบุเวลา';
      default: return format;
    }
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
        String finalRemark = remark.trim().isEmpty ? 'ไม่ระบุเหตุผล (ไม่อนุมัติ)' : '${remark.trim()} (ไม่อนุมัติ)';
        await ref.read(leaveProvider.notifier).reject(req.id, finalRemark);
        if (mounted) SnackbarUtils.showLeft(context, 'ปฏิเสธใบลาสำเร็จ');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy');

    final title = _selectedView == 'PENDING'
        ? 'รายการใบลาที่รออนุมัติ'
        : 'ประวัติการลาทั้งหมด';

    final list = _selectedView == 'PENDING' ? leaveState.pending : leaveState.history;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HrTabHeader(
            title: title,
            onRefresh: () async {
              try {
                await LeaveSyncService().syncLeaveRequestsFromCloud();
              } catch (_) {}
              ref.read(leaveProvider.notifier).loadPending();
              ref.read(leaveProvider.notifier).loadAllHistory();
              if (context.mounted) {
                SnackbarUtils.showLeft(context, 'ซิงค์ใบลาจากคลาวด์เรียบร้อย');
              }
            },
            onCreate: () {
              showDialog(
                context: context,
                builder: (context) => const LeaveFormDialog(),
              );
            },
            createLabel: 'สร้างใบลา',
            createIcon: Icons.add,
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
            child: leaveState.isLoading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text(
                          _selectedView == 'PENDING'
                              ? 'ไม่มีใบลาที่รอการอนุมัติ'
                              : 'ไม่มีประวัติการลา',
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: HrStatusUtils.getStatusColor(req.status).withValues(alpha: 0.1),
                                child: Icon(
                                  req.status == 'APPROVED' ? Icons.check_circle : req.status == 'REJECTED' ? Icons.cancel : Icons.description,
                                  color: HrStatusUtils.getStatusColor(req.status),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  HrStatusBadge(status: req.status, type: HrItemType.leave),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${_formatLeaveType(req.leaveType)} (${_formatLeaveFormat(req.leaveFormat)}) - ${req.totalDays} วัน'),
                                  if (req.leaveFormat == 'HOURLY')
                                    Text('เวลา: ${dateFormat.format(req.startDate)} - ${dateFormat.format(req.endDate)}')
                                  else
                                    Text('วันที่: ${dateOnlyFormat.format(req.startDate)} - ${dateOnlyFormat.format(req.endDate)}'),
                                  if (req.reason != null && req.reason!.isNotEmpty)
                                    Text('เหตุผล: ${req.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                  if (req.status == 'REJECTED' && req.rejectReason != null && req.rejectReason!.isNotEmpty)
                                    Text('เหตุผลที่ปฏิเสธ: ${req.rejectReason}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
                                  Text('ยื่นเมื่อ: ${dateFormat.format(req.createdAt ?? DateTime.now())}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                                  : null,
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
