import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../state/hr/employee_provider.dart';

/// Filter bar for the payroll history view.
/// Extracted from PayrollHistoryView build method (filter section).
class PayrollHistoryFilterBar extends ConsumerWidget {
  final DateTime historyStart;
  final DateTime historyEnd;
  final int? historyEmployeeFilter;
  final DateFormat dateFormat;
  final VoidCallback onSelectRange;
  final void Function(int days) onSelectQuickRange;
  final void Function(int? val) onEmployeeFilterChanged;

  const PayrollHistoryFilterBar({
    super.key,
    required this.historyStart,
    required this.historyEnd,
    required this.historyEmployeeFilter,
    required this.dateFormat,
    required this.onSelectRange,
    required this.onSelectQuickRange,
    required this.onEmployeeFilterChanged,
  });

  Widget _chip(String label, int days) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => onSelectQuickRange(days),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeeProvider).employees;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onSelectRange,
          icon: const Icon(Icons.calendar_month),
          label: Text('${dateFormat.format(historyStart)} - ${dateFormat.format(historyEnd)}'),
        ),
        const SizedBox(width: 8),
        _chip('สัปดาห์นี้', 7),
        const SizedBox(width: 4),
        _chip('เดือนนี้', 30),
        const SizedBox(width: 4),
        _chip('3 เดือน', 90),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int?>(
            initialValue: historyEmployeeFilter,
            decoration: const InputDecoration(
              labelText: 'พนักงาน',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
              ...employees.map((e) => DropdownMenuItem<int?>(
                    value: e.id,
                    child: Text(e.displayName ?? 'ID: ${e.id}', overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onEmployeeFilterChanged,
          ),
        ),
      ],
    );
  }
}
