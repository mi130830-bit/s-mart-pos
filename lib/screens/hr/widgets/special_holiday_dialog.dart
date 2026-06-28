import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../state/hr/attendance_provider.dart';
import '../../../services/alert_service.dart';

class SpecialHolidayDialog extends ConsumerStatefulWidget {
  const SpecialHolidayDialog({super.key});

  @override
  ConsumerState<SpecialHolidayDialog> createState() => _SpecialHolidayDialogState();
}

class _SpecialHolidayDialogState extends ConsumerState<SpecialHolidayDialog> {
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
            const Text('เพิ่มวันหยุดพิเศษ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('d MMM yyyy').format(_selectedDate)),
                  onPressed: _pickDate,
                ),
                const SizedBox(width: 8),
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
