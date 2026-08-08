import 'dart:async';
import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../state/hr/attendance_provider.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../widgets/dialogs/admin_pin_dialog.dart';
import '../../../services/alert_service.dart';

// Extracted widgets
import '../widgets/attendance/attendance_employee_row.dart';
import '../widgets/attendance/special_holiday_banner.dart';
import '../widgets/attendance/special_holiday_dialog.dart';
import '../widgets/shared/hr_confirm_dialog.dart';

class HrAttendanceTab extends ConsumerStatefulWidget {
  const HrAttendanceTab({super.key});

  @override
  ConsumerState<HrAttendanceTab> createState() => _HrAttendanceTabState();
}

class _HrAttendanceTabState extends ConsumerState<HrAttendanceTab> {
  Timer? _refreshTimer;
  bool _isAutoRefreshing = false;

  @override
  void initState() {
    super.initState();
    // S-Link writes attendance directly to MySQL through the POS API. Poll
    // while this tab is open so a mobile check-in appears without requiring
    // the cashier to press Refresh.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshAttendanceSilently(),
    );
  }

  Future<void> _refreshAttendanceSilently() async {
    if (!mounted || _isAutoRefreshing) return;
    _isAutoRefreshing = true;
    try {
      await ref.read(attendanceProvider.notifier).loadToday();
    } finally {
      _isAutoRefreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final employeeState = ref.watch(employeeProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📋 สถานะพนักงานวันนี้ (${DateFormat('d MMM yyyy').format(DateTime.now())})',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (attendanceState.isLoading)
                  const CircularProgressIndicator(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.beach_access, color: Colors.teal),
                      tooltip: 'จัดการวันหยุดพิเศษ',
                      onPressed: _showSpecialHolidayDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.warning_amber_rounded,
                          color: Colors.deepOrange),
                      tooltip: 'ปิดร้านฉุกเฉิน (Clock Out ทุกคน)',
                      onPressed: _emergencyClose,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'รีเฟรชข้อมูลลงเวลาล่าสุด',
                      onPressed: () async {
                        await ref.read(attendanceProvider.notifier).loadToday();
                        if (context.mounted) {
                          final error = ref.read(attendanceProvider).error;
                          SnackbarUtils.showLeft(
                            context,
                            error == null
                                ? 'รีเฟรชข้อมูลลงเวลาเรียบร้อย'
                                : 'รีเฟรชไม่สำเร็จ: $error',
                            isError: error != null,
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: 'ล้างรายการเข้าออกงานทั้งหมด',
                      onPressed: _clearAllAttendance,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            // ✅ Extracted SpecialHolidayBanner widget
            if (attendanceState.specialHolidays.isNotEmpty)
              SpecialHolidayBanner(holidays: attendanceState.specialHolidays),

            Expanded(
              child: ListView.separated(
                itemCount: employeeState.employees.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final emp = employeeState.employees[index];
                  final log = attendanceState.todayAttendance
                      .where((a) => a.employeeId == emp.id)
                      .firstOrNull;
                  final isOnTempLeave =
                      log != null && log.activeTempLeaveRound != null;

                  // ✅ Extracted AttendanceEmployeeRow widget
                  return AttendanceEmployeeRow(
                      emp: emp, log: log, isOnTempLeave: isOnTempLeave);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Clear All Attendance
  // ---------------------------------------------------------------------------

  void _clearAllAttendance() async {
    final isAuthorized = await AdminPinDialog.show(
      context,
      title: 'ยืนยันสิทธิ์',
      message: 'กรุณากรอกรหัสผ่านแอดมินเพื่อล้างรายการเข้าออกงานทั้งหมด',
    );

    if (!isAuthorized) {
      if (mounted) {
        AlertService.show(
            context: context,
            message: 'รหัสผ่านไม่ถูกต้อง หรือยกเลิกการทำรายการ',
            type: 'error');
      }
      return;
    }

    if (!mounted) return;
    // ✅ ใช้ HrConfirmDialog แทน inline AlertDialog
    final confirm = await HrConfirmDialog.show(
      context,
      title: 'ยืนยันการล้างข้อมูล',
      content:
          'คุณต้องการล้างรายการเข้าออกงานทั้งหมดในระบบใช่หรือไม่?\n\n(การกระทำนี้ไม่สามารถย้อนกลับได้)',
      actionLabel: 'ล้างข้อมูล',
      actionColor: Colors.red,
      titleIcon: Icons.warning_amber_rounded,
      actionIcon: Icons.delete_forever,
    );

    if (confirm) {
      if (!mounted) return;
      try {
        await ref.read(attendanceProvider.notifier).clearAllLogs();
        if (mounted) {
          AlertService.show(
              context: context,
              message: 'ล้างรายการเข้าออกงานทั้งหมดเรียบร้อยแล้ว',
              type: 'success');
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(
              context: context,
              message: 'เกิดข้อผิดพลาด: ${e.toString()}',
              type: 'error');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Emergency Close Shop
  // ---------------------------------------------------------------------------

  void _emergencyClose() async {
    final isAuthorized = await AdminPinDialog.show(
      context,
      title: '🚨 ปิดร้านฉุกเฉิน',
      message: 'กรุณากรอกรหัสผ่านแอดมินเพื่อยืนยัน',
    );
    if (!isAuthorized) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'ยกเลิกการทำรายการ', type: 'error');
      }
      return;
    }

    if (!mounted) return;
    final reasonController = TextEditingController(text: 'ปิดร้านฉุกเฉิน');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('ยืนยันปิดร้านฉุกเฉิน',
                style: TextStyle(color: Colors.deepOrange)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ระบบจะ Clock Out พนักงานทุกคนที่ยังเข้างานอยู่ทันที'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                border: OutlineInputBorder(),
                hintText: 'เช่น ไฟดับ, ปิดร้านฉุกเฉิน',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.power_settings_new),
            label: const Text('ปิดร้านเลย'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final reason = reasonController.text.trim().isEmpty
            ? 'EMERGENCY_CLOSE'
            : reasonController.text.trim();
        final count = await ref
            .read(attendanceProvider.notifier)
            .emergencyCloseShop(reason);
        if (mounted) {
          AlertService.show(
            context: context,
            message: count > 0
                ? 'ปิดร้านเรียบร้อย! Clock Out $count คน 🟢'
                : 'ไม่มีพนักงานที่ต้องปิดร้าน (ทุกคนเลิกงานหมดแล้ว)',
            type: count > 0 ? 'success' : 'info',
          );
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(
              context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Special Holiday Dialog
  // ---------------------------------------------------------------------------

  void _showSpecialHolidayDialog() async {
    final isAuthorized = await AdminPinDialog.show(
      context,
      title: '🏖️ วันหยุดพิเศษ',
      message: 'กรุณากรอกรหัสผ่านแอดมินเพื่อจัดการวันหยุดพิเศษ',
    );
    if (!isAuthorized) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'ยกเลิกการทำรายการ', type: 'error');
      }
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => const SpecialHolidayDialog(),
    );
    if (mounted) ref.read(attendanceProvider.notifier).loadToday();
  }
}
