import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/leave_request.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/leave_provider.dart';
import '../widgets/leave_form_dialog.dart';

class HrLeaveTab extends ConsumerStatefulWidget {
  const HrLeaveTab({super.key});

  @override
  ConsumerState<HrLeaveTab> createState() => _HrLeaveTabState();
}

class _HrLeaveTabState extends ConsumerState<HrLeaveTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(leaveProvider.notifier).loadPending());
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'CANCELLED': return Colors.grey;
      default: return Colors.orange;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'APPROVED': return 'อนุมัติแล้ว';
      case 'REJECTED': return 'ปฏิเสธ';
      case 'CANCELLED': return 'ยกเลิก';
      default: return 'รออนุมัติ';
    }
  }

  Future<void> _showApproveDialog(LeaveRequest req) async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ อนุมัติใบลา'),
        content: Text('ต้องการอนุมัติการลางานของ ${req.employeeName ?? 'พนักงาน'} หรือไม่?'),
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
        await ref.read(leaveProvider.notifier).approve(req.id, authState.currentUser!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อนุมัติใบลาสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        }
      }
    }
  }

  Future<void> _showRejectDialog(LeaveRequest req) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ ปฏิเสธใบลา'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('เหตุผลที่ปฏิเสธการลาของ ${req.employeeName ?? 'พนักงาน'}:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'กรอกเหตุผล...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('ยืนยันปฏิเสธ'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ref.read(leaveProvider.notifier).reject(req.id, result.isEmpty ? 'ไม่ระบุเหตุผล' : result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ปฏิเสธใบลาสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการใบลาที่รออนุมัติ',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => ref.read(leaveProvider.notifier).loadPending(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('รีเฟรช'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const LeaveFormDialog(),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('สร้างใบลา'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: leaveState.isLoading && leaveState.pending.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : leaveState.pending.isEmpty
                    ? const Center(child: Text('ไม่มีใบลาที่รอการอนุมัติ', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListView.separated(
                          itemCount: leaveState.pending.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final req = leaveState.pending[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                child: const Icon(Icons.description, color: Colors.blue),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                                  Text('${_formatLeaveType(req.leaveType)} (${_formatLeaveFormat(req.leaveFormat)}) - ${req.totalDays} วัน'),
                                  if (req.leaveFormat == 'HOURLY')
                                    Text('เวลา: ${dateFormat.format(req.startDate)} - ${dateFormat.format(req.endDate)}')
                                  else
                                    Text('วันที่: ${dateOnlyFormat.format(req.startDate)} - ${dateOnlyFormat.format(req.endDate)}'),
                                  if (req.reason != null && req.reason!.isNotEmpty)
                                    Text('เหตุผล: ${req.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                  Text('ยื่นเมื่อ: ${dateFormat.format(req.createdAt ?? DateTime.now())}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              trailing: Row(
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
                              ),
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
