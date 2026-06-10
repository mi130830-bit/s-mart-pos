import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/excel_export_service.dart';
import '../../services/alert_service.dart';
import '../../repositories/delivery_history_repository.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../../services/mysql_service.dart';
import '../../services/firestore_rest_service.dart';
import 'package:flutter/foundation.dart';

import 'widgets/delivery_report/delivery_report_filter_bar.dart';
import 'widgets/delivery_report/delivery_report_vehicle_chips.dart';
import 'widgets/delivery_report/delivery_report_data_table.dart';
import 'widgets/delivery_report/assign_vehicle_dialog.dart';

class DeliveryReportScreen extends StatefulWidget {
  // ✅ Task 4: รับ Service แบบ Optional (Option B) — ไม่ต้องแต่ main.dart
  final DeliveryIntegrationService? deliveryService;

  const DeliveryReportScreen({super.key, this.deliveryService});

  @override
  State<DeliveryReportScreen> createState() => _DeliveryReportScreenState();
}

class _DeliveryReportScreenState extends State<DeliveryReportScreen> {
  final DeliveryHistoryRepository _repo = DeliveryHistoryRepository();
  final ExcelExportService _exportService = ExcelExportService();

  bool _isLoading = false;
  bool _isExporting = false;
  bool _isSyncing = false; // ✅ Task 4
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _allVehicles = [];
  String? _selectedVehicle;
  String _searchQuery = '';

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _endDate = DateTime.now();


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final start = DateTime(
          _startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final end =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final db = MySQLService();

      // ── 1. ดึงรถจาก MySQL vehicle_settings (Base) ──
      final vehicleResult = await db.query('SELECT * FROM vehicle_settings');
      // Map: plate (upper) -> row
      final Map<String, Map<String, dynamic>> vehicleMap = {};
      for (final v in vehicleResult) {
        final plate = v['vehicle_plate']?.toString().trim().toUpperCase() ?? '';
        if (plate.isNotEmpty) vehicleMap[plate] = Map<String, dynamic>.from(v);
      }

      // ── 2. Merge กับ Firestore cars collection (Source of Truth) ──
      try {
        List<Map<String, dynamic>> carsData = [];
        if (defaultTargetPlatform == TargetPlatform.windows) {
          carsData = await FirestoreRestService.fetchCars();
        } else {
          final snapshot = await FirebaseFirestore.instance
              .collection('cars')
              .orderBy('name')
              .get();
          carsData = snapshot.docs.map((d) => d.data()).toList();
        }

        for (final data in carsData) {
          final name = data['name']?.toString().trim() ?? '';
          final plate = data['licensePlate']?.toString().trim().toUpperCase() ?? '';
          if (plate.isEmpty && name.isEmpty) continue;

          final key = plate.isNotEmpty ? plate : name.toUpperCase();
          if (vehicleMap.containsKey(key)) {
            // เสริมข้อมูลชื่อรถ (vehicle_type) จาก Firestore
            if ((vehicleMap[key]!['vehicle_type']?.toString() ?? '').isEmpty && name.isNotEmpty) {
              vehicleMap[key]!['vehicle_type'] = name;
            }
          } else {
            // รถที่มีใน Firestore แต่ยังไม่เคยส่งของ → เพิ่มให้ครบ
            vehicleMap[key] = {
              'vehicle_plate': plate.isNotEmpty ? plate : name,
              'vehicle_type': name,
              'fuel_efficiency': 7.0,
            };
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DeliveryReport] Firestore cars load failed: $e');
        // Fallback: ใช้แค่ vehicle_settings
      }

      final mergedVehicles = vehicleMap.values.toList()
        ..sort((a, b) {
          final pa = a['vehicle_plate']?.toString() ?? '';
          final pb = b['vehicle_plate']?.toString() ?? '';
          return pa.compareTo(pb);
        });

      final records = await _repo.getHistoryByDateRange(start, end);

      // 🛠️ Fallback cleanup for old records to ensure UI displays them correctly
      for (var record in records) {
        String vehicle = record['vehiclePlate']?.toString().trim().toUpperCase() ?? '';
        String driver = record['driverName']?.toString().trim() ?? '';
        
        if (vehicle.isEmpty && driver.contains(',')) {
          final parts = driver.split(',').map((e) => e.trim()).toList();
          final lastPart = parts.last;
          if (lastPart.contains('รถ') || 
              lastPart.contains('ดั้ม') || 
              lastPart.contains('กระบะ') || 
              lastPart.contains('กะบะ') || 
              lastPart.contains('ใหญ่') ||
              lastPart.contains('เล็ก') ||
              lastPart.contains('โฟล์ค') ||
              lastPart.contains('ลิฟท์')) {
            record['vehiclePlate'] = lastPart.toUpperCase();
            record['driverName'] = parts.sublist(0, parts.length - 1).join(', ');
          }
        }
      }

      // 🌟 ดึง distanceKm จากตาราง customer มาเสริม record ที่ยังไม่มีระยะทาง
      final Map<String, double> customerDistanceCache = {};
      for (var record in records) {
        final dist = double.tryParse(record['distanceKm']?.toString() ?? '0') ?? 0.0;
        if (dist == 0.0) {
          final cname = record['customerName']?.toString().trim() ?? '';
          if (cname.isNotEmpty && cname != 'ลูกค้าทั่วไป') {
            if (!customerDistanceCache.containsKey(cname)) {
              try {
                final res = await db.query(
                  'SELECT distanceKm FROM customer WHERE CONCAT(firstName, " ", IFNULL(lastName, "")) LIKE :n OR firstName LIKE :n LIMIT 1',
                  {'n': '%$cname%'},
                );
                if (res.isNotEmpty) {
                  final d = double.tryParse(res.first['distanceKm']?.toString() ?? '0') ?? 0.0;
                  customerDistanceCache[cname] = d;
                } else {
                  customerDistanceCache[cname] = 0.0;
                }
              } catch (_) {
                customerDistanceCache[cname] = 0.0;
              }
            }
            final customerDist = customerDistanceCache[cname] ?? 0.0;
            if (customerDist > 0.0) {
              record['distanceKm'] = customerDist;
              record['_distanceSource'] = 'customer';
            }
          }
        } else {
          record['_distanceSource'] = 'history';
        }
      }

      if (mounted) {
        setState(() {
          _records = records;
          _allVehicles = mergedVehicles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.show(
            context: context,
            message: 'โหลดข้อมูลไม่สำเร็จ: $e',
            type: 'error');
      }
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(backgroundColor: Theme.of(context).colorScheme.surface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate; // auto adjust end date if needed
        }
      });
      await _loadData();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(backgroundColor: Theme.of(context).colorScheme.surface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
      await _loadData();
    }
  }

  Future<void> _exportExcel() async {
    if (_filteredRecords.isEmpty) {
      AlertService.show(
          context: context,
          message: 'ไม่มีข้อมูลในช่วงที่เลือก หรือตามรถที่กรอง',
          type: 'warning');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final success =
          await _exportService.exportDeliveryReport(_filteredRecords, _startDate, _endDate, allVehicles: _allVehicles);
      if (mounted) {
        AlertService.show(
          context: context,
          message: success
              ? 'สร้างไฟล์ Excel สำเร็จ กำลังเปิดไฟล์...'
              : 'เกิดข้อผิดพลาดในการสร้างไฟล์ Excel',
          type: success ? 'success' : 'error',
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'Error: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ✅ Task 4: Sync จาก Cloud ก่อนแสดง — ใช้ Service ที่ส่งเข้ามา (Option B)
  Future<void> _syncFromCloud() async {
    if (widget.deliveryService == null) {
      AlertService.show(
          context: context,
          message: 'ไม่พบระบบ Sync — กรุณา Restart แอป',
          type: 'warning');
      return;
    }
    setState(() => _isSyncing = true);
    try {
      await widget.deliveryService!.syncNow();
      await _loadData(); // โหลดคืนหลัง Sync
      if (mounted) {
        AlertService.show(
            context: context,
            message: 'ดึงข้อมูลล่าสุดจาก Cloud สำเร็จ!',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'Sync ล้มเหลว: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ✅ Update vehicle plate in MySQL and refresh UI
  Future<void> _updateVehiclePlate(Map<String, dynamic> record, String newPlate) async {
    final id = record['id'];
    if (id == null) return;
    try {
      await MySQLService().execute(
        'UPDATE delivery_history SET vehiclePlate = :plate WHERE id = :id',
        {'plate': newPlate.trim().toUpperCase(), 'id': id},
      );
      setState(() {
        record['vehiclePlate'] = newPlate.trim().toUpperCase();
      });
      if (mounted) {
        AlertService.show(context: context, message: '✅ ปรับรถ "$newPlate" เรียบร้อย', type: 'success');
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'ผิดพลาด: $e', type: 'error');
      }
    }
  }

  void _handleAssignVehicle(Map<String, dynamic> record) {
    showAssignVehicleDialog(
      context,
      record,
      _allVehicles,
      (String plate) => _updateVehiclePlate(record, plate),
    );
  }

  String _normalizePlate(String value) {
    if (value.trim().isEmpty) return 'ไม่ระบุ';
    final v = value.trim().toUpperCase();
    for (var vehicle in _allVehicles) {
      final plate = vehicle['vehicle_plate']?.toString().trim().toUpperCase() ?? '';
      final type = vehicle['vehicle_type']?.toString().trim().toUpperCase() ?? '';
      if (plate == v || (type.isNotEmpty && type == v)) {
        return vehicle['vehicle_plate']?.toString() ?? v;
      }
    }
    return value.trim();
  }

  // Properties
  List<Map<String, dynamic>> get _filteredRecords {
    var result = _records;

    if (_selectedVehicle != null) {
      result = result.where((r) {
        final raw = r['vehiclePlate']?.toString() ?? '';
        final v = _normalizePlate(raw);
        return v == _selectedVehicle;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) {
        final customerName = r['customerName']?.toString().toLowerCase() ?? '';
        final driverName = r['driverName']?.toString().toLowerCase() ?? '';
        return customerName.contains(q) || driverName.contains(q);
      }).toList();
    }

    return result;
  }

  // Summary stats
  double get _totalAmount =>
      _filteredRecords.fold(0.0, (total, r) => total + (double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0));

  double get _totalFuelCost {
    return _filteredRecords.fold(0.0, (total, r) {
      final fuel = double.tryParse(r['fuelCostEstimate']?.toString() ?? '0') ?? 0.0;
      return total + fuel;
    });
  }

  Map<String, int> get _countByVehicle {
    final map = <String, int>{};
    // ✅ ดึงรถที่ลงทะเบียนไว้ (Firestore + vehicle_settings) มาแสดงเสมอ แม้ยังไม่มี record ให้
    for (var v in _allVehicles) {
      final plate = v['vehicle_plate']?.toString().trim().toUpperCase() ?? '';
      if (plate.isNotEmpty) map[plate] = 0;
    }
    // นับจาก records จริง
    for (var r in _records) {
      final raw = r['vehiclePlate']?.toString() ?? '';
      final v = _normalizePlate(raw);
      map[v] = (map[v] ?? 0) + 1;
    }
    // ซ่อน: ถ้า 'ไม่ระบุ' มี  0 ให้เอาออก (ไม่แสดง)
    if ((map['ไม่ระบุ'] ?? 0) == 0) map.remove('ไม่ระบุ');
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานการจัดส่ง'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          // ✅ Task 4: ปุ่ม Sync จาก Cloud
          if (widget.deliveryService != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: OutlinedButton.icon(
                onPressed: (_isSyncing || _isLoading) ? null : _syncFromCloud,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onPrimary,
                  side: BorderSide(color: colorScheme.onPrimary.withValues(alpha: 0.5)),
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_sync_outlined, size: 18),
                label: Text(_isSyncing ? 'กำลัง Sync...' : 'ดึงข้อมูลจาก Cloud'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _exportExcel,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download),
              label: Text(_isExporting ? 'กำลัง Export...' : 'Export Excel'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ──────────────────────────────────────────
          DeliveryReportFilterBar(
            startDate: _startDate,
            endDate: _endDate,
            searchQuery: _searchQuery,
            totalCount: _filteredRecords.length,
            totalAmount: _totalAmount,
            totalFuelCost: _totalFuelCost,
            onPickStartDate: _pickStartDate,
            onPickEndDate: _pickEndDate,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          // ── Vehicle Summary Chips ────────────────────────────────
          if (_countByVehicle.isNotEmpty && !_isLoading)
            DeliveryReportVehicleChips(
              countByVehicle: _countByVehicle,
              allVehicles: _allVehicles,
              selectedVehicle: _selectedVehicle,
              onVehicleSelected: (plate) {
                setState(() {
                  _selectedVehicle = plate;
                });
              },
            ),

          // ── Data Table ─────────────────────────────────────────
          Expanded(
            child: DeliveryReportDataTable(
              isLoading: _isLoading,
              filteredRecords: _filteredRecords,
              onEmptyAction: _pickStartDate,
              onAssignVehicle: _handleAssignVehicle,
            ),
          ),
        ],
      ),
    );
  }
}
