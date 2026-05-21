import 'package:flutter/material.dart';

class DeliveryReportVehicleChips extends StatelessWidget {
  final Map<String, int> countByVehicle;
  final List<Map<String, dynamic>> allVehicles;
  final String? selectedVehicle;
  final Function(String?) onVehicleSelected;

  const DeliveryReportVehicleChips({
    super.key,
    required this.countByVehicle,
    required this.allVehicles,
    required this.selectedVehicle,
    required this.onVehicleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Text('รถ: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      selectedColor: colorScheme.primaryContainer,
                      backgroundColor: Colors.indigo.shade50,
                      checkmarkColor: colorScheme.primary,
                    ),
                  ),
                  ...countByVehicle.entries.map((e) {
                    final plate = e.key;
                    final count = e.value;
                    String displayName = plate;
                    if (plate != 'ไม่ระบุ') {
                      final matched = allVehicles
                          .where((v) =>
                              (v['vehicle_plate']?.toString().trim().toUpperCase() ?? '') == plate)
                          .toList();
                      if (matched.isNotEmpty) {
                        final type = matched.first['vehicle_type']?.toString().trim() ?? '';
                        if (type.isNotEmpty) displayName = '$type $plate';
                      }
                    }
                    final isSelected = selectedVehicle == plate;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('$displayName ($count)'),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          onVehicleSelected(selected ? plate : null);
                        },
                        selectedColor: colorScheme.primaryContainer,
                        backgroundColor: Colors.indigo.shade50,
                        checkmarkColor: colorScheme.primary,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
