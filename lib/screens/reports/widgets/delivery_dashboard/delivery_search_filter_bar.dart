import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/common/quick_date_range_selector.dart';

class DeliverySearchFilterBar extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String? selectedVehicle;
  final Map<String, int> countByVehicle;
  final List<Map<String, dynamic>> allVehicles;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final void Function(String?) onVehicleSelected;
  final ValueChanged<DateTimeRange> onDateRangeChanged;

  const DeliverySearchFilterBar({
    super.key,
    required this.startDate,
    required this.endDate,
    this.selectedVehicle,
    required this.countByVehicle,
    required this.allVehicles,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onVehicleSelected,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date Filter Bar ──────────────────────────────────────────
        Container(
          color: Colors.indigo.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuickDateRangeSelector(
                currentRange: DateTimeRange(start: startDate, end: endDate),
                onChanged: onDateRangeChanged,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
              const Icon(Icons.date_range, size: 20, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('เริ่ม:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onPickStartDate,
                child: Text(
                  dateFormat.format(startDate),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              const Text('ถึง:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onPickEndDate,
                child: Text(
                  dateFormat.format(endDate),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
                ],
              ),
            ],
          ),
        ),

        // ── Vehicle Filter Chips ─────────────────────────────────────
        if (countByVehicle.isNotEmpty)
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'รถ: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('ทั้งหมด'),
                            selected: selectedVehicle == null,
                            onSelected: (_) => onVehicleSelected(null),
                            selectedColor: Colors.indigo.shade100,
                            checkmarkColor: Colors.indigo,
                          ),
                        ),
                        ...countByVehicle.entries.map((e) {
                          final plate = e.key;
                          final count = e.value;

                          // Find display name
                          String displayName = plate;
                          if (plate != 'ไม่ระบุ') {
                            final matched = allVehicles
                                .where((v) =>
                                    (v['vehicle_plate']
                                            ?.toString()
                                            .trim()
                                            .toUpperCase() ??
                                        '') ==
                                    plate)
                                .toList();
                            if (matched.isNotEmpty) {
                              final type = matched.first['vehicle_type']
                                      ?.toString()
                                      .trim() ??
                                  '';
                              if (type.isNotEmpty) {
                                displayName = '$type $plate';
                              }
                            }
                          }

                          final isSelected = selectedVehicle == plate;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text('$displayName ($count)'),
                              selected: isSelected,
                              onSelected: (v) =>
                                  onVehicleSelected(v ? plate : null),
                              selectedColor: Colors.indigo.shade100,
                              checkmarkColor: Colors.indigo,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
