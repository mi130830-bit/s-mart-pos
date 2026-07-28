import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/hr/employee_provider.dart';
import '../widgets/employee/employee_form_dialog.dart';
import '../widgets/employee/employee_list_tile.dart';
import '../widgets/shared/hr_empty_state.dart';

import 'dart:async';

class HrEmployeeTab extends ConsumerStatefulWidget {
  const HrEmployeeTab({super.key});

  @override
  ConsumerState<HrEmployeeTab> createState() => _HrEmployeeTabState();
}

class _HrEmployeeTabState extends ConsumerState<HrEmployeeTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(employeeProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
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
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ค้นหาพนักงาน (ชื่อ, รหัส, เบอร์โทร, ตำแหน่ง)...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)))
                    : state.employees.isEmpty
                        ? const HrEmptyState(icon: Icons.people_outline, message: 'ไม่พบข้อมูลพนักงาน')
                        : ReorderableListView.builder(
                            itemCount: state.employees.length,
                            onReorder: (oldIndex, newIndex) {
                              if (_searchController.text.isNotEmpty) {
                                // Ignore reorder while searching to avoid index mismatch
                                return;
                              }
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
