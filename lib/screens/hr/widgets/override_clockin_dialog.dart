import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hr/employee_profile.dart';
import '../../../state/auth_provider.dart';
import '../../../state/hr/attendance_provider.dart';

class OverrideClockinDialog extends ConsumerStatefulWidget {
  final EmployeeProfile employee;
  final String actionType; // 'IN', 'OUT', 'TEMP_LEAVE', 'TEMP_RETURN'

  const OverrideClockinDialog({super.key, required this.employee, required this.actionType});

  /// หัวข้อเหตุผลที่สามารถเพิ่มได้ในอนาคต โดยเพิ่มรายการใน list นี้
  static const List<String> presetReasons = [
    'มือถือหาย/ลืม',
    'ลืมแสกนเข้า/ออก',
  ];

  /// ค่าพิเศษสำหรับ "อื่นๆ (ระบุเอง)"
  static const String _customReasonKey = '__custom__';

  @override
  ConsumerState<OverrideClockinDialog> createState() => _OverrideClockinDialogState();
}

class _OverrideClockinDialogState extends ConsumerState<OverrideClockinDialog> {
  final _customReasonController = TextEditingController();
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  /// ค่าที่เลือกจาก Dropdown (null = ยังไม่เลือก)
  String? _selectedReason;

  /// ส่งค่า reason จริงที่จะบันทึก
  String get _finalReason {
    if (_selectedReason == OverrideClockinDialog._customReasonKey) {
      return _customReasonController.text.trim();
    }
    return _selectedReason ?? '';
  }

  @override
  void initState() {
    super.initState();
    final now = widget.actionType == 'OUT' ? const TimeOfDay(hour: 17, minute: 0) : TimeOfDay.now();
    _hourController = TextEditingController(text: now.hour.toString().padLeft(2, '0'));
    _minuteController = TextEditingController(text: now.minute.toString().padLeft(2, '0'));

    _hourFocus.addListener(() {
      if (_hourFocus.hasFocus) {
        _hourController.selection = TextSelection(baseOffset: 0, extentOffset: _hourController.text.length);
      }
    });

    _minuteFocus.addListener(() {
      if (_minuteFocus.hasFocus) {
        _minuteController.selection = TextSelection(baseOffset: 0, extentOffset: _minuteController.text.length);
      }
    });
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authState = ref.read(authProvider);
    if (authState.currentUser == null) return;

    if (_selectedReason == null) {
      SnackbarUtils.showLeft(context, 'กรุณาเลือกเหตุผลในการลงเวลาแทน');
      return;
    }

    if (_selectedReason == OverrideClockinDialog._customReasonKey &&
        _customReasonController.text.trim().isEmpty) {
      SnackbarUtils.showLeft(context, 'กรุณาระบุเหตุผลในการลงเวลาแทน');
      return;
    }

    final reason = _finalReason;

    final int hour = int.tryParse(_hourController.text) ?? TimeOfDay.now().hour;
    final int minute = int.tryParse(_minuteController.text) ?? TimeOfDay.now().minute;
    final selectedTime = TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));

    try {
      switch (widget.actionType) {
        case 'IN':
          await ref.read(attendanceProvider.notifier).clockInOverride(
            widget.employee.id, authState.currentUser!.id, selectedTime, reason);
          break;
        case 'OUT':
          await ref.read(attendanceProvider.notifier).clockOutOverride(
            widget.employee.id, authState.currentUser!.id, selectedTime, reason);
          break;
        case 'TEMP_LEAVE':
          await ref.read(attendanceProvider.notifier).startTempLeaveOverride(
            widget.employee.id, authState.currentUser!.id, selectedTime, reason);
          break;
        case 'TEMP_RETURN':
          await ref.read(attendanceProvider.notifier).endTempLeaveOverride(
            widget.employee.id, authState.currentUser!.id, selectedTime, reason);
          break;
      }

      if (mounted) {
        Navigator.pop(context, true);
        SnackbarUtils.showLeft(context, 'บันทึกการลงเวลาแทนสำเร็จ');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selectedReason == OverrideClockinDialog._customReasonKey;

    return AlertDialog(
      title: Text(_getDialogTitle()),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('พนักงาน: ${widget.employee.displayName ?? 'ไม่ระบุชื่อ'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.grey),
                const SizedBox(width: 16),
                const Text('เวลา:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _hourController,
                    focusNode: _hourFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _minuteController,
                    focusNode: _minuteFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Dropdown เลือกเหตุผล
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'เหตุผลการลงเวลาแทน',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              hint: const Text('เลือกเหตุผล'),
              items: [
                // รายการ preset
                for (final reason in OverrideClockinDialog.presetReasons)
                  DropdownMenuItem(value: reason, child: Text(reason)),
                // ตัวเลือกระบุเอง
                const DropdownMenuItem(
                  value: OverrideClockinDialog._customReasonKey,
                  child: Text('อื่นๆ (ระบุเอง)'),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedReason = value);
                if (value != OverrideClockinDialog._customReasonKey) {
                  _customReasonController.clear();
                }
              },
            ),

            // ช่องพิมพ์เหตุผลเอง (แสดงเฉพาะเมื่อเลือก "อื่นๆ")
            if (isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customReasonController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ระบุเหตุผล',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: const Text('บันทึกข้อมูล'),
        ),
      ],
    );
  }

  String _getDialogTitle() {
    switch (widget.actionType) {
      case 'IN': return '📝 ลงเวลาเข้างานให้พนักงาน';
      case 'OUT': return '📝 ลงเวลาออกงานให้พนักงาน';
      case 'TEMP_LEAVE': return '📝 ลงเวลาออกชั่วคราวให้พนักงาน';
      case 'TEMP_RETURN': return '📝 ลงเวลากลับเข้างานให้พนักงาน';
      default: return '📝 จัดการลงเวลา';
    }
  }
}
