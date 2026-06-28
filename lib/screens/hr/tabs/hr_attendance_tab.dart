import 'dart:async';
import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../state/hr/attendance_provider.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../models/hr/employee_profile.dart';
import '../../../models/hr/attendance_log.dart';
import '../widgets/override_clockin_dialog.dart';
import '../../../widgets/dialogs/admin_pin_dialog.dart';
import '../../../services/alert_service.dart';
import '../../../services/hr/attendance_sync_service.dart';
import '../widgets/special_holiday_dialog.dart';
import '../widgets/temp_leave_timeline.dart';
class HrAttendanceTab extends ConsumerStatefulWidget {
  const HrAttendanceTab({super.key});

  @override
  ConsumerState<HrAttendanceTab> createState() => _HrAttendanceTabState();
}

class _HrAttendanceTabState extends ConsumerState<HrAttendanceTab> {
  // Timer สำหรับเดิน realtime วัดเวลาออกชั่วคราว
  Timer? _realtimeTimer;
  int _tickCount = 0; // ใช้ trigger setState เพื่อ update timer

  @override
  void initState() {
    super.initState();
    // Timer เดินทุก 30 วินาที เพื่อ update นาฬิกาออกชั่วคราว realtime
    _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _tickCount++);
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (attendanceState.isLoading)
                  const CircularProgressIndicator(),
                Row(
                  children: [
                    // ปุ่มวันหยุดพิเศษ
                    IconButton(
                      icon: const Icon(Icons.beach_access, color: Colors.teal),
                      tooltip: 'จัดการวันหยุดพิเศษ',
                      onPressed: _showSpecialHolidayDialog,
                    ),
                    // ปุ่มปิดร้านฉุกเฉิน
                    IconButton(
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                      tooltip: 'ปิดร้านฉุกเฉิน (Clock Out ทุกคน)',
                      onPressed: _emergencyClose,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'รีเฟรชข้อมูลจากคลาวด์',
                      onPressed: () async {
                        // Sync จาก Firestore ก่อน
                        await AttendanceSyncService().syncAttendanceFromCloud(force: true);
                        // แล้วค่อยโหลดข้อมูลลง UI
                        if (context.mounted) {
                          ref.read(attendanceProvider.notifier).loadToday();
                          SnackbarUtils.showLeft(context, 'ซิงค์ข้อมูลลงเวลาจากคลาวด์เรียบร้อย');
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

            // ส่วนแสดงวันหยุดพิเศษ (ถ้ามี)
            if (attendanceState.specialHolidays.isNotEmpty) ..._buildSpecialHolidayBanner(attendanceState.specialHolidays),
            
            Expanded(
              child: ListView.separated(
                itemCount: employeeState.employees.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final emp = employeeState.employees[index];
                  
                  // Find attendance info
                  final log = attendanceState.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  final isOnTempLeave = log != null && log.activeTempLeaveRound != null;
                  
                  return _buildEmployeeRow(emp, log, isOnTempLeave);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllAttendance() async {
    // 1. Ask for Admin PIN
    final isAuthorized = await AdminPinDialog.show(
      context,
      title: 'ยืนยันสิทธิ์',
      message: 'กรุณากรอกรหัสผ่านแอดมินเพื่อล้างรายการเข้าออกงานทั้งหมด',
    );

    if (!isAuthorized) {
      if (mounted) {
         AlertService.show(context: context, message: 'รหัสผ่านไม่ถูกต้อง หรือยกเลิกการทำรายการ', type: 'error');
      }
      return;
    }

    // 2. Confirm Dialog
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการล้างข้อมูล', style: TextStyle(color: Colors.red)),
        content: const Text('คุณต้องการล้างรายการเข้าออกงานทั้งหมดในระบบใช่หรือไม่?\n\n(การกระทำนี้ไม่สามารถย้อนกลับได้)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ล้างข้อมูล'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        await ref.read(attendanceProvider.notifier).clearAllLogs();
        if (mounted) {
           AlertService.show(context: context, message: 'ล้างรายการเข้าออกงานทั้งหมดเรียบร้อยแล้ว', type: 'success');
        }
      } catch (e) {
        if (mounted) {
           AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: ${e.toString()}', type: 'error');
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
      if (mounted) AlertService.show(context: context, message: 'ยกเลิกการทำรายการ', type: 'error');
      return;
    }

    if (!mounted) return;
    // รับหมายเหตุการปิด
    final reasonController = TextEditingController(text: 'ปิดร้านฉุกเฉิน');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('ยืนยันปิดร้านฉุกเฉิน', style: TextStyle(color: Colors.deepOrange)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final reason = reasonController.text.trim().isEmpty ? 'EMERGENCY_CLOSE' : reasonController.text.trim();
        final count = await ref.read(attendanceProvider.notifier).emergencyCloseShop(reason);
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
        if (mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
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
      if (mounted) AlertService.show(context: context, message: 'ยกเลิกการทำรายการ', type: 'error');
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => const SpecialHolidayDialog(),
    );
    // โหลดข้อมูลใหม่หลังปิด dialog
    if (mounted) ref.read(attendanceProvider.notifier).loadToday();
  }

  // ---------------------------------------------------------------------------
  // Special Holiday Banner (แสดงในรายการถ้าวันนี้เป็นวันหยุดพิเศษ)
  // ---------------------------------------------------------------------------

  List<Widget> _buildSpecialHolidayBanner(List<dynamic> holidays) {
    final today = DateTime.now();
    final todayHoliday = holidays.where((h) {
      final d = h.date;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).firstOrNull;

    if (todayHoliday == null) return [];
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.beach_access, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🏖️ วันหยุดพิเศษ: ${todayHoliday.name} — พนักงานรายเดือนไม่นับขาดงานวันนี้',
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildEmployeeRow(EmployeeProfile emp, AttendanceLog? log, bool isOnTempLeave) {
    String status = 'ยังไม่เข้างาน';
    IconData icon = Icons.person_off;
    Color color = Colors.grey;

    final attendanceState = ref.read(attendanceProvider);
    final todayLeave = attendanceState.todayApprovedLeaves.where((l) => l.employeeId == emp.id).firstOrNull;

    if (log != null) {
      if (log.clockOut != null) {
        status = 'เลิกงานแล้ว (${DateFormat('HH:mm').format(log.clockOut!)})';
        icon = Icons.check_circle_outline;
        color = Colors.blueGrey;
      } else if (isOnTempLeave) {
        // คำนวณเวลาที่ออกไปนานแล้ว (realtime) จากรอบที่ active
        final activeOut = log.latestTempOutTime!;
        final elapsed = DateTime.now().difference(activeOut);
        final roundNum = log.activeTempLeaveRound!;
        final roundSuffix = roundNum > 1 ? ' (รอบ $roundNum)' : '';
        status = 'ออกชั่วคราว$roundSuffix • ออกไป ${_formatDuration(elapsed)} แล้ว';
        icon = Icons.pause_circle_filled;
        color = Colors.orange;
      } else {
        status = 'เข้างาน (${DateFormat('HH:mm').format(log.clockIn!)})';
        icon = Icons.check_circle;
        color = Colors.green;
      }
    } else if (todayLeave != null) {
      status = 'วันนี้ลา (${todayLeave.leaveType == 'PERSONAL' ? 'ลากิจ' : todayLeave.leaveType == 'SICK' ? 'ลาป่วย' : todayLeave.leaveType == 'VACATION' ? 'ลาพักร้อน' : todayLeave.leaveType == 'MATERNITY' ? 'ลาคลอด' : 'อื่นๆ'})';
      icon = Icons.beach_access;
      color = Colors.teal;
    }

    // ตรวจว่ามีประวัติ temp-out ที่เสร็จแล้วอย่างน้อย 1 รอบ
    final hasTempHistory = log != null && log.completedTempLeaveRounds > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          title: Text(emp.displayName ?? 'ไม่ระบุชื่อ'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              if (todayLeave != null && todayLeave.reason != null && todayLeave.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('หมายเหตุ: ${todayLeave.reason}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
              // ถ้าออกชั่วคราวอยู่ แสดง inline timeline
              if (isOnTempLeave && log != null)
                  TempLeaveTimeline(log: log, isOnTempLeave: true)
            ],
          ),
          isThreeLine: isOnTempLeave || hasTempHistory,
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'จัดการลงเวลาให้',
            onSelected: (actionType) async {
              if (actionType == 'DELETE_TODAY') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ล้างข้อมูลการลงเวลาวันนี้'),
                    content: Text('คุณต้องการล้างข้อมูลการเข้า-ออกงานวันนี้ของ "${emp.displayName}" ใช่หรือไม่?\n(ใช้ในการทดสอบระบบเพื่อให้สามารถทดสอบสแกนนิ้วใหม่ได้)'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('ล้างข้อมูล'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  try {
                    await ref.read(attendanceProvider.notifier).deleteTodayLog(emp.id);
                    if (mounted) {
                      AlertService.show(context: context, message: 'ล้างข้อมูลของ ${emp.displayName} เรียบร้อยแล้วครับ 🟢', type: 'success');
                    }
                  } catch (e) {
                    if (mounted) {
                      AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e ❌', type: 'error');
                    }
                  }
                }
              } else {
                showDialog(
                  context: context,
                  builder: (context) => OverrideClockinDialog(employee: emp, actionType: actionType),
                );
              }
            },
            itemBuilder: (context) => [
              if (log == null)
                const PopupMenuItem(value: 'IN', child: Text('เข้างาน')),
              if (log != null && log.clockOut == null && !isOnTempLeave && log.canStartNewTempLeave)
                const PopupMenuItem(value: 'OUT', child: Text('ออกงาน')),
              if (log != null && log.clockOut == null && !isOnTempLeave && log.canStartNewTempLeave)
                const PopupMenuItem(value: 'TEMP_LEAVE', child: Text('ออกชั่วคราว')),
              if (isOnTempLeave)
                const PopupMenuItem(value: 'TEMP_RETURN', child: Text('กลับเข้างาน')),
              if (log != null)
                const PopupMenuItem(
                  value: 'DELETE_TODAY',
                  child: Text('ล้างข้อมูลวันนี้ (ใช้ทดสอบ)', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        // โซน Timeline เต็ม (แสดงเสมอ ไม่ต้องซ่อน)
        if (hasTempHistory)
          TempLeaveTimeline(log: log, isOnTempLeave: false),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) return '${duration.inMinutes} นาที';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours ชม. $minutes นาที';
  }
}

