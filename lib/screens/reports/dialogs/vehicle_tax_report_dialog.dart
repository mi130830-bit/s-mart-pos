import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../repositories/delivery_history_repository.dart';
import '../../../services/excel_export_service.dart';

class VehicleTaxReportDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const VehicleTaxReportDialog({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<VehicleTaxReportDialog> createState() => _VehicleTaxReportDialogState();
}

class _VehicleTaxReportDialogState extends State<VehicleTaxReportDialog> {
  final DeliveryHistoryRepository _repo = DeliveryHistoryRepository();
  final ExcelExportService _exportService = ExcelExportService();

  bool _isLoading = false;
  bool _isExporting = false;
  
  List<String> _vehicles = [];
  final Map<String, TextEditingController> _odoControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  @override
  void dispose() {
    for (var ctrl in _odoControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    if (widget.endDate.difference(widget.startDate).inDays > 366) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final records = await _repo.getHistoryByDateRange(widget.startDate, widget.endDate);
      
      final Set<String> vehicleSet = {};
      for (var record in records) {
        final plate = record['vehiclePlate']?.toString().trim() ?? '';
        if (plate.isNotEmpty && plate != '-' && !plate.contains('โฟล์คลิฟท์')) {
          vehicleSet.add(plate);
        }
      }

      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _vehicles = vehicleSet.toList()..sort();
        // Initialize controllers for new vehicles
        for (var v in _vehicles) {
          if (!_odoControllers.containsKey(v)) {
            final lastOdo = prefs.getDouble('last_odo_$v') ?? 0.0;
            _odoControllers[v] = TextEditingController(
              text: lastOdo > 0 ? lastOdo.toStringAsFixed(1) : '0'
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching vehicles: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    if (_vehicles.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final records = await _repo.getHistoryByDateRange(widget.startDate, widget.endDate);
      
      // Parse initial odometers and save next odometers
      final Map<String, double> initialOdos = {};
      final prefs = await SharedPreferences.getInstance();

      for (var v in _vehicles) {
        final startOdo = double.tryParse(_odoControllers[v]?.text ?? '0') ?? 0.0;
        initialOdos[v] = startOdo;

        // Calculate total distance for this vehicle in this period
        double totalDist = 0.0;
        for (var record in records) {
          final plate = record['vehiclePlate']?.toString().trim() ?? '';
          if (plate == v) {
            totalDist += double.tryParse(record['distanceKm']?.toString() ?? '0') ?? 0.0;
          }
        }
        // Save the end odometer for next time
        await prefs.setDouble('last_odo_$v', startOdo + totalDist);
      }

      final success = await _exportService.exportDeliveryReport(
        records,
        widget.startDate,
        widget.endDate,
        initialOdometers: initialOdos,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'สร้างไฟล์ Excel เรียบร้อยแล้ว' : 'ไม่พบข้อมูลในการสร้างรายงาน'),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            width: 400,
          ),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            width: 400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.directions_car, color: Colors.blue),
          SizedBox(width: 10),
          Text('สร้างรายงานจัดส่ง & บำรุงรักษารถ'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ระบุเลขไมล์เริ่มต้นสำหรับรถแต่ละคัน (เพื่อคำนวณไมล์ไปกลับ)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 10),
            const Text(
              'กรุณาระบุเลขไมล์เริ่มต้นในช่วงเวลานี้ สำหรับรถแต่ละคัน:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '💡 ระบบจะจำเลขไมล์ล่าสุด และทบยอดระยะทางให้อัตโนมัติในครั้งถัดไป',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
            const SizedBox(height: 10),
            
            if (widget.endDate.difference(widget.startDate).inDays > 366)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('❌ ไม่สามารถสร้างรายงานได้\nกรุณาเลือกช่วงเวลาไม่เกิน 1 ปีเพื่อป้องกันระบบค้าง', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
              ))
            else if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ))
            else if (_vehicles.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('ไม่พบประวัติการวิ่งรถในเดือนนี้', style: TextStyle(color: Colors.grey)),
              ))
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final v = _vehicles[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(v, style: const TextStyle(fontSize: 16)),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _odoControllers[v],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'เลขไมล์เริ่มต้น',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton.icon(
          onPressed: _vehicles.isEmpty || _isExporting || widget.endDate.difference(widget.startDate).inDays > 366 ? null : _export,
          icon: _isExporting 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.download),
          label: Text(_isExporting ? 'กำลังสร้าง...' : 'Export Excel'),
        ),
      ],
    );
  }
}
