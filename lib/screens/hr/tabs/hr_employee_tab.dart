import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/hr/employee_provider.dart';
import '../widgets/employee/employee_form_dialog.dart';
import '../widgets/employee/employee_list_tile.dart';
import '../widgets/shared/hr_empty_state.dart';

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
                onPressed: () => EmployeeFormDialog.show(context),
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
                        ? const HrEmptyState(icon: Icons.people_outline, message: 'ยังไม่มีข้อมูลพนักงาน')
                        : ReorderableListView.builder(
                            itemCount: state.employees.length,
                            onReorder: (oldIndex, newIndex) {
                              ref.read(employeeProvider.notifier).reorderEmployees(oldIndex, newIndex);
                            },
                            // ✅ Using extracted EmployeeListTile widget
                            itemBuilder: (context, index) => EmployeeListTile(
                              key: ValueKey(state.employees[index].id),
                              emp: state.employees[index],
                              onEdit: (emp) => EmployeeFormDialog.show(context, employee: emp),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
