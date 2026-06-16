import 'dart:async';
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
                  final isOnTempLeave = log != null && log.tempOut != null && log.backToWork == null;
                  
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

  // แปลง Duration เป็น "นน นาที" หรือ "นน ชั่วม นน นาที"
  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '$h ชั่วม $m นาที' : '$h ชั่วม';
    }
    return '${d.inMinutes} นาที';
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
      builder: (ctx) => _SpecialHolidayDialog(),
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

    if (log != null) {
      if (log.clockOut != null) {
        status = 'เลิกงานแล้ว (${DateFormat('HH:mm').format(log.clockOut!)})';
        icon = Icons.check_circle_outline;
        color = Colors.blueGrey;
      } else if (isOnTempLeave) {
        // คำนวณเวลาที่ออกไปนานแล้ว (realtime)
        final elapsed = DateTime.now().difference(log.tempOut!);
        status = 'ออกชั่วคราว • ออกไป ${_formatDuration(elapsed)} แล้ว';
        icon = Icons.pause_circle_filled;
        color = Colors.orange;
      } else {
        status = 'เข้างาน (${DateFormat('HH:mm').format(log.clockIn!)})';
        icon = Icons.check_circle;
        color = Colors.green;
      }
    }

    // ตรวจว่ามีประวัติ temp-out ที่เสร็จแล้ว (backToWork != null)
    final hasTempHistory = log != null && log.tempOut != null && log.backToWork != null;

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
              // ถ้าออกชั่วคราวอยู่ แสดง inline timeline
              if (isOnTempLeave && log != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildInlineTempLeaveActive(log),
                ),
              // ถ้ากลับเข้างานแล้ว ลบ chip แบบซ่อนออก เพื่อให้ไปโชว์ใน timeline เต็มๆ ด้านล่างเลย
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
              if (log != null && log.clockOut == null && !isOnTempLeave)
                const PopupMenuItem(value: 'OUT', child: Text('ออกงาน')),
              if (log != null && log.clockOut == null && !isOnTempLeave)
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
          _buildExpandedTimeline(log),
      ],
    );
  }

  /// Timeline แบบ inline ตอนออกชั่วคราวอยู่ (เดิน realtime)
  Widget _buildInlineTempLeaveActive(AttendanceLog log) {
    final elapsed = DateTime.now().difference(log.tempOut!);
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (log.clockIn != null)
          _buildTimeChip(
            Icons.login, DateFormat('HH:mm').format(log.clockIn!),
            Colors.green, 'เข้า',
          ),
        const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
        _buildTimeChip(
          Icons.directions_run, DateFormat('HH:mm').format(log.tempOut!),
          Colors.orange, 'ออก',
        ),
        const Icon(Icons.more_horiz, size: 12, color: Colors.orange),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '⏱ ${_formatDuration(elapsed)}',
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Timeline เต็ม ตอน expand ดู history
  Widget _buildExpandedTimeline(AttendanceLog? log) {
    if (log == null) return const SizedBox.shrink();
    final duration = log.backToWork != null && log.tempOut != null
        ? log.backToWork!.difference(log.tempOut!)
        : null;
    return Container(
      margin: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ประวัติออกชั่วคราว',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Step 1: เข้างาน
              if (log.clockIn != null) ...[
                _buildTimelineStep(
                  icon: Icons.login,
                  label: 'เข้างาน',
                  time: DateFormat('HH:mm').format(log.clockIn!),
                  color: Colors.green,
                ),
                _buildTimelineConnector(null),
              ],
              // Step 2: ออกชั่วคราว
              if (log.tempOut != null)
                _buildTimelineStep(
                  icon: Icons.directions_run,
                  label: 'ออกชั่วคราว',
                  time: DateFormat('HH:mm').format(log.tempOut!),
                  color: Colors.orange,
                ),
              // Connector พร้อมเวลาที่ออกไป
              if (log.tempOut != null && log.backToWork != null)
                _buildTimelineConnector(duration),
              // Step 3: กลับเข้างาน
              if (log.backToWork != null)
                _buildTimelineStep(
                  icon: Icons.keyboard_return,
                  label: 'กลับเข้า',
                  time: DateFormat('HH:mm').format(log.backToWork!),
                  color: Colors.blue,
                ),
            ],
          ),
          if (duration != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⏱ ออกนอกรวม ${_formatDuration(duration)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text('$label $time', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({required IconData icon, required String label, required String time, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTimelineConnector(Duration? duration) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.orange.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          if (duration != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 9, color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SpecialHolidayDialog: Dialog จัดการวันหยุดพิเศษ (เพิ่ม / ลบ)
// =============================================================================

class _SpecialHolidayDialog extends ConsumerStatefulWidget {
  const _SpecialHolidayDialog();

  @override
  ConsumerState<_SpecialHolidayDialog> createState() => _SpecialHolidayDialogState();
}

class _SpecialHolidayDialogState extends ConsumerState<_SpecialHolidayDialog> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _addHoliday() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AlertService.show(context: context, message: 'กรุณาระบุชื่อวันหยุด', type: 'error');
      return;
    }
    try {
      await ref.read(attendanceProvider.notifier).addSpecialHoliday(_selectedDate, name);
      if (mounted) {
        _nameController.clear();
        AlertService.show(
          context: context,
          message: 'เพิ่มวันหยุดพิเศษ "$name" (${DateFormat('d MMM yyyy').format(_selectedDate)}) เรียบร้อย 🟢',
          type: 'success',
        );
      }
    } catch (e) {
      if (mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
    }
  }

  Future<void> _removeHoliday(DateTime date, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบวันหยุด'),
        content: Text('ต้องการลบวันหยุดพิเศษ "$name" ออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(attendanceProvider.notifier).removeSpecialHoliday(date);
        if (mounted) AlertService.show(context: context, message: 'ลบวันหยุดพิเศษเรียบร้อย', type: 'success');
      } catch (e) {
        if (mounted) AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final holidays = ref.watch(attendanceProvider).specialHolidays;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.beach_access, color: Colors.teal),
          SizedBox(width: 8),
          Text('จัดการวันหยุดพิเศษ', style: TextStyle(color: Colors.teal)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนเพิ่มวันหยุดใหม่
            const Text('เพิ่มวันหยุดพิเศษ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                // ปุ่มเลือกวันที่
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('d MMM yyyy').format(_selectedDate)),
                  onPressed: _pickDate,
                ),
                const SizedBox(width: 8),
                // ช่องชื่อวันหยุด
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อวันหยุด',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'เช่น ปิดร้านกะทันหัน',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: _addHoliday,
                ),
              ],
            ),
            const Divider(height: 24),
            // รายการวันหยุดพิเศษที่มีอยู่
            const Text('รายการวันหยุดพิเศษ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (holidays.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('ยังไม่มีวันหยุดพิเศษในระบบ', style: TextStyle(color: Colors.grey)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: holidays.length,
                  itemBuilder: (context, index) {
                    final h = holidays[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.beach_access, color: Colors.teal, size: 20),
                      title: Text(h.name),
                      subtitle: Text(DateFormat('EEEE d MMMM yyyy', 'th').format(h.date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'ลบวันหยุดนี้',
                        onPressed: () => _removeHoliday(h.date, h.name),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}
