import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/hr/employee_provider.dart';
import '../widgets/employee_form_dialog.dart';

class HrEmployeeTab extends ConsumerWidget {
  const HrEmployeeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employeeProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายชื่อพนักงานทั้งหมด',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  EmployeeFormDialog.show(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มพนักงาน'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)))
                    : state.employees.isEmpty
                        ? const Center(child: Text('ยังไม่มีข้อมูลพนักงาน'))
                        : ReorderableListView.builder(
                            itemCount: state.employees.length,
                            onReorder: (oldIndex, newIndex) {
                              ref.read(employeeProvider.notifier).reorderEmployees(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final emp = state.employees[index];
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
                                        onPressed: () {
                                          EmployeeFormDialog.show(context, employee: emp);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        tooltip: 'ลบ/ลาออก',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              title: const Text('ยืนยันลบพนักงาน'),
                                              content: Text('คุณต้องการลบพนักงาน ${emp.displayName} หรือไม่?\n(พนักงานจะถูกตั้งค่าเป็น "ลาออก/ไม่ใช้งาน" เพื่อเก็บประวัติไว้)'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
                                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
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
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
