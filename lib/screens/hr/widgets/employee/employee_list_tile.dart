import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../state/hr/employee_provider.dart';
import '../../../../utils/snackbar_utils.dart';
import '../shared/hr_confirm_dialog.dart';

/// Employee list tile for HrEmployeeTab.
/// Extracted from HrEmployeeTab itemBuilder.
class EmployeeListTile extends ConsumerWidget {
  final dynamic emp; // EmployeeProfile
  final void Function(dynamic emp) onEdit;

  const EmployeeListTile({
    super.key,
    required this.emp,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: ValueKey(emp.id),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(emp.roleType == 'DRIVER' ? '🚗' : '🏢'),
        ),
        title: Text(
          emp.displayName?.isNotEmpty == true ? emp.displayName! : 'ไม่มีชื่อ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text([
          'ประเภท: ${emp.roleType}',
          'ค่าจ้าง: ${emp.wageType}',
        ].join(' | ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'แก้ไข',
              onPressed: () => onEdit(emp),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'ลบ/ลาออก',
              onPressed: () async {
                final confirm = await HrConfirmDialog.show(
                  context,
                  title: 'ยืนยันลบพนักงาน',
                  content: 'คุณต้องการลบพนักงาน ${emp.displayName} หรือไม่?\n(พนักงานจะถูกตั้งค่าเป็น "ลาออก/ไม่ใช้งาน" เพื่อเก็บประวัติไว้)',
                  actionLabel: 'ลบ',
                  actionColor: Colors.red,
                  actionIcon: Icons.delete,
                );
                if (confirm) {
                  try {
                    await ref.read(employeeProvider.notifier).deactivate(emp.id);
                    if (context.mounted) SnackbarUtils.showLeft(context, 'ลบพนักงานเรียบร้อยแล้ว');
                  } catch (e) {
                    if (context.mounted) SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
                  }
                }
              },
            ),
            const SizedBox(width: 16),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
