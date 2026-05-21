import 'package:flutter/material.dart';

class AssignVehicleDialog extends StatelessWidget {
  final Map<String, dynamic> record;
  final List<Map<String, dynamic>> allVehicles;
  final Function(String) onAssign;

  const AssignVehicleDialog({
    super.key,
    required this.record,
    required this.allVehicles,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เลือกรถ'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current assignment
              if ((record['vehiclePlate']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'รถปัจจุบัน: ${record['vehiclePlate']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              // Vehicle list
              ...allVehicles.map((v) {
                final plate = v['vehicle_plate']?.toString() ?? '';
                final name = v['vehicle_type']?.toString() ?? '';
                final label = name.isNotEmpty ? '$name ($plate)' : plate;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_car, color: Colors.indigo),
                  title: Text(label),
                  subtitle: plate.isNotEmpty && name.isNotEmpty ? Text(plate, style: const TextStyle(fontSize: 12)) : null,
                  onTap: () {
                    Navigator.pop(context);
                    onAssign(plate);
                  },
                );
              }),
              // Clear option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.clear, color: Colors.red),
                title: const Text('ลบข้อมูลรถ'),
                onTap: () {
                  Navigator.pop(context);
                  onAssign('');
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
      ],
    );
  }
}

Future<void> showAssignVehicleDialog(
  BuildContext context,
  Map<String, dynamic> record,
  List<Map<String, dynamic>> allVehicles,
  Function(String) onAssign,
) {
  return showDialog(
    context: context,
    builder: (ctx) => AssignVehicleDialog(
      record: record,
      allVehicles: allVehicles,
      onAssign: onAssign,
    ),
  );
}
