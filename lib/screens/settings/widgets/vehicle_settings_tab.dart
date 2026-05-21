import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleSettingsTab extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> vehicles;
  final VoidCallback onAddVehicle;
  final VoidCallback onSyncFromHistory;
  final void Function(Map<String, dynamic> row) onEditVehicle;
  final void Function(Map<String, dynamic> row) onDeleteVehicle;

  const VehicleSettingsTab({
    super.key,
    required this.isLoading,
    required this.vehicles,
    required this.onAddVehicle,
    required this.onSyncFromHistory,
    required this.onEditVehicle,
    required this.onDeleteVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFormat = NumberFormat('#,##0.00');

    return Column(
      children: [
        // Header Banner
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('อัตราสิ้นเปลืองน้ำมันต่อคัน',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      'ใช้ในการคำนวณต้นทุนน้ำมัน (ลิตร = ระยะทาง ÷ กม./ลิตร)',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSyncFromHistory,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync จากประวัติ'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAddVehicle,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรถ'),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : vehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('ยังไม่มีข้อมูลรถ',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: onSyncFromHistory,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync จากประวัติส่งของ'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: onAddVehicle,
                                icon: const Icon(Icons.add),
                                label: const Text('เพิ่มรถใหม่'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(cs.primary.withValues(alpha: 0.1)),
                        columns: const [
                          DataColumn(label: Text('ทะเบียนรถ')),
                          DataColumn(label: Text('อัตราสิ้นเปลือง'), numeric: true),
                          DataColumn(label: Text('ประเภทรถ')),
                          DataColumn(label: Text('หมายเหตุ')),
                          DataColumn(label: Text('จัดการ')),
                        ],
                        rows: vehicles.map((row) {
                          final eff =
                              double.tryParse(row['fuel_efficiency']?.toString() ?? '7') ?? 7.0;
                          return DataRow(cells: [
                            DataCell(Text(
                              row['vehicle_plate']?.toString() ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              '${moneyFormat.format(eff)} กม./ลิตร',
                              style: TextStyle(
                                  color: cs.primary, fontWeight: FontWeight.w600),
                            )),
                            DataCell(Text(
                                row['vehicle_type']?.toString().isEmpty == false
                                    ? row['vehicle_type']
                                    : '-')),
                            DataCell(Text(
                                row['note']?.toString().isEmpty == false
                                    ? row['note']
                                    : '-')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: 'แก้ไข',
                                  onPressed: () => onEditVehicle(row),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  tooltip: 'ลบ',
                                  onPressed: () => onDeleteVehicle(row),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}
