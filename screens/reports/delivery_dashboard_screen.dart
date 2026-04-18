import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/delivery_history_repository.dart';
import '../../services/mysql_service.dart';
import '../../repositories/fuel_price_repository.dart';
import '../../repositories/vehicle_settings_repository.dart';
import '../../services/alert_service.dart';
import '../../services/integration/delivery_integration_service.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  final DeliveryIntegrationService? deliveryService;
  const DeliveryDashboardScreen({super.key, this.deliveryService});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final DeliveryHistoryRepository _repo = DeliveryHistoryRepository();
  final FuelPriceRepository _fuelRepo = FuelPriceRepository();
  final VehicleSettingsRepository _vehicleRepo = VehicleSettingsRepository();

  bool _isLoading = false;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _records = [];
  Map<String, double> _priceLookup = {};
  Map<String, double> _efficiencyMap = {};
  List<Map<String, dynamic>> _allVehicles = [];

  String? _selectedVehicle;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm');
  final _moneyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      // ── 1. ดึงรถจาก MySQL vehicle_settings (Base) ──
      final vehicleResult = await _vehicleRepo.getAllVehicles();
      final Map<String, Map<String, dynamic>> vehicleMap = {};
      for (final v in vehicleResult) {
        final plate = v['vehicle_plate']?.toString().trim().toUpperCase() ?? '';
        if (plate.isNotEmpty) vehicleMap[plate] = Map<String, dynamic>.from(v);
      }

      // ── 2. Merge กับ Firestore cars collection (Source of Truth) ──
      try {
        final snapshot = await FirebaseFirestore.instance.collection('cars').orderBy('name').get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = data['name']?.toString().trim() ?? '';
          final plate = data['licensePlate']?.toString().trim().toUpperCase() ?? '';
          if (plate.isEmpty && name.isEmpty) continue;

          final key = plate.isNotEmpty ? plate : name.toUpperCase();
          if (vehicleMap.containsKey(key)) {
            if ((vehicleMap[key]!['vehicle_type']?.toString() ?? '').isEmpty && name.isNotEmpty) {
              vehicleMap[key]!['vehicle_type'] = name;
            }
          } else {
            vehicleMap[key] = {
              'vehicle_plate': plate.isNotEmpty ? plate : name,
              'vehicle_type': name,
              'fuel_efficiency': 7.0,
            };
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DeliveryDashboard] Firestore cars load failed: $e');
      }

      final mergedVehicles = vehicleMap.values.toList()
        ..sort((a, b) {
          final pa = a['vehicle_plate']?.toString() ?? '';
          final pb = b['vehicle_plate']?.toString() ?? '';
          return pa.compareTo(pb);
        });

      final results = await Future.wait([
        _repo.getHistoryByDateRange(start, end),
        _fuelRepo.buildPriceLookup(start, end),
        _vehicleRepo.getEfficiencyMap(),
      ]);

      if (mounted) {
        setState(() {
          _records = results[0] as List<Map<String, dynamic>>;
          _priceLookup = results[1] as Map<String, double>;
          _efficiencyMap = results[2] as Map<String, double>;
          _allVehicles = mergedVehicles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.show(context: context, message: 'โหลดข้อมูลไม่สำเร็จ: $e', type: 'error');
      }
    }
  }

  Future<void> _syncFromCloud() async {
    if (widget.deliveryService == null) {
      AlertService.show(context: context, message: 'ไม่พบระบบ Sync — กรุณา Restart แอป', type: 'warning');
      return;
    }
    setState(() => _isSyncing = true);
    try {
      await widget.deliveryService!.syncNow();
      await _loadData();
      if (mounted) AlertService.show(context: context, message: 'ดึงข้อมูลล่าสุดจาก Cloud สำเร็จ!', type: 'success');
    } catch (e) {
      if (mounted) AlertService.show(context: context, message: 'Sync ล้มเหลว: $e', type: 'error');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate.isBefore(_startDate) ? _startDate : _endDate),
      firstDate: isStart ? DateTime(2020) : _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(dialogTheme: DialogThemeData(backgroundColor: Theme.of(context).colorScheme.surface)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() { isStart ? _startDate = picked : _endDate = picked; });
      await _loadData();
    }
  }

  // ── Computed Props ────────────────────────────────────────────────

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
      if (mounted) AlertService.show(context: context, message: 'ผิดพลาด: $e', type: 'error');
    }
  }

  void _showAssignVehicleDialog(BuildContext context, Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('เลือกรถ'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((record['vehiclePlate']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('รถปัจจุบัน: ${record['vehiclePlate']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ),
                ..._allVehicles.map((v) {
                  final plate = v['vehicle_plate']?.toString() ?? '';
                  final name = v['vehicle_type']?.toString() ?? '';
                  final label = name.isNotEmpty ? '$name ($plate)' : plate;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.directions_car, color: Colors.indigo),
                    title: Text(label),
                    subtitle: plate.isNotEmpty && name.isNotEmpty ? Text(plate, style: const TextStyle(fontSize: 12)) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateVehiclePlate(record, plate);
                    },
                  );
                }),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.clear, color: Colors.red),
                  title: const Text('ลบข้อมูลรถ'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateVehiclePlate(record, '');
                  },
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก'))],
        );
      },
    );
  }

  String _normalizePlate(String raw) {
    if (raw.trim().isEmpty) return 'ไม่ระบุ';
    final normalized = raw.trim().toUpperCase();
    for (var v in _allVehicles) {
      final p = (v['vehicle_plate']?.toString() ?? '').trim().toUpperCase();
      final t = (v['vehicle_type']?.toString() ?? '').trim().toUpperCase();
      if (p.isNotEmpty && (normalized == p || (t.isNotEmpty && normalized == t))) {
        return p; 
      }
    }
    return normalized;
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_selectedVehicle == null) return _records;
    return _records.where((r) {
      final v = r['vehiclePlate']?.toString() ?? '';
      return _normalizePlate(v) == _selectedVehicle;
    }).toList();
  }

  Map<String, int> get _countByVehicle {
    final map = <String, int>{};
    // Initialize all registered vehicles with 0
    for (var v in _allVehicles) {
      final plate = (v['vehicle_plate']?.toString() ?? '').trim().toUpperCase();
      if (plate.isNotEmpty) {
        map[plate] = 0;
      }
    }
    // Count from records
    for (var r in _records) {
      final rawPlate = r['vehiclePlate']?.toString() ?? '';
      final plate = _normalizePlate(rawPlate);
      map[plate] = (map[plate] ?? 0) + 1;
    }
    if ((map['ไม่ระบุ'] ?? 0) == 0) map.remove('ไม่ระบุ');
    return map;
  }

  // คำนวณค่าน้ำมันของรอบ 1 รายการ
  double _calculateJobFuelCost(Map<String, dynamic> r) {
    final dist = double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0;
    if (dist <= 0) return 0.0;

    final rawPlate = r['vehiclePlate']?.toString() ?? '';
    final plate = _normalizePlate(rawPlate);

    double fuelPrice = 0.0;
    final rawDate = r['completedAt']?.toString() ?? '';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        fuelPrice = FuelPriceRepository.resolvePriceFromLookup(_priceLookup, dt);
      } catch (_) {}
    }

    final eff = _efficiencyMap[plate] ?? VehicleSettingsRepository.defaultEfficiency;
    final liters = dist / eff;
    return liters * fuelPrice;
  }

  double get _totalDistance => _filteredRecords.fold(0.0, (s, r) => s + (double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0));
  double get _totalAmount => _filteredRecords.fold(0.0, (s, r) => s + (double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0));
  double get _totalFuelCost => _filteredRecords.fold(0.0, (s, r) => s + _calculateJobFuelCost(r));
  int get _missingDistanceCount => _filteredRecords.where((r) => (double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0) == 0.0).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามงานส่งของ'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (widget.deliveryService != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: (_isSyncing || _isLoading) ? null : _syncFromCloud,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: _isSyncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_sync_outlined, size: 18),
                label: Text(_isSyncing ? 'กำลัง Sync...' : 'ดึงข้อมูลจาก Cloud'),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date Filter Bar ──────────────────────────────────────────
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text('เริ่ม:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _pickDate(isStart: true),
                  child: Text(_dateFormat.format(_startDate), style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 12),
                const Text('ถึง:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _pickDate(isStart: false),
                  child: Text(_dateFormat.format(_endDate), style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),

          // ── Summary Cards ────────────────────────────────────────────
          if (!_isLoading)
            Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _summaryCard(
                    label: 'งานทั้งหมด',
                    value: '${_filteredRecords.length} งาน',
                    icon: Icons.local_shipping_outlined,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    label: 'ระยะทางรวม',
                    value: '${_moneyFormat.format(_totalDistance)} กม.',
                    icon: Icons.route_outlined,
                    color: Colors.blue,
                    subtitle: '* จากข้อมูลลูกค้าในระบบ',
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    label: 'ยอดเงินรวม',
                    value: '฿${_moneyFormat.format(_totalAmount)}',
                    icon: Icons.payments_outlined,
                    color: Colors.green,
                    large: true,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    label: 'ค่าน้ำมันรวม',
                    value: '฿${_moneyFormat.format(_totalFuelCost)}',
                    icon: Icons.local_gas_station_outlined,
                    color: Colors.orange,
                  ),
                  if (_missingDistanceCount > 0) ...[
                    const SizedBox(width: 10),
                    _summaryCard(
                      label: 'ไม่มีระยะทาง',
                      value: '$_missingDistanceCount รายการ',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      subtitle: 'กรอกระยะทางในข้อมูลลูกค้า',
                    ),
                  ],
                ],
              ),
            ),

          // ── Vehicle Filter Chips ─────────────────────────────────────
          if (_countByVehicle.isNotEmpty && !_isLoading)
            Container(
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('รถ: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
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
                              selected: _selectedVehicle == null,
                              onSelected: (_) => setState(() => _selectedVehicle = null),
                              selectedColor: Colors.indigo.shade100,
                              checkmarkColor: Colors.indigo,
                            ),
                          ),
                          ..._countByVehicle.entries.map((e) {
                            final plate = e.key;
                            final count = e.value;
                            // Find display name
                            String displayName = plate;
                            if (plate != 'ไม่ระบุ') {
                              final matched = _allVehicles.where((v) => (v['vehicle_plate']?.toString().trim().toUpperCase() ?? '') == plate).toList();
                              if (matched.isNotEmpty) {
                                final type = matched.first['vehicle_type']?.toString().trim() ?? '';
                                if (type.isNotEmpty) displayName = '$type $plate';
                              }
                            }
                            final isSelected = _selectedVehicle == plate;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text('$displayName ($count)'),
                                selected: isSelected,
                                onSelected: (v) => setState(() => _selectedVehicle = v ? plate : null),
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

          // ── Job Cards ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 72, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('ไม่พบข้อมูลในช่วงที่เลือก', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => _pickDate(isStart: true),
                              child: const Text('เปลี่ยนช่วงวันที่'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) => _buildJobCard(_filteredRecords[index], cs),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Summary Card (style เดียวกับ fuel_summary_screen) ───────────────
  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool large = false,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: color, fontSize: 12)),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: large ? 18 : 15,
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Job Card ─────────────────────────────────────────────────────────
  Widget _buildJobCard(Map<String, dynamic> r, ColorScheme cs) {
    final rawDate = r['completedAt']?.toString() ?? '';
    String dateStr = '-';
    String timeStr = '';
    try {
      if (rawDate.isNotEmpty) {
        final dt = DateTime.parse(rawDate);
        dateStr = _dateFormat.format(dt);
        timeStr = _timeFormat.format(dt);
      }
    } catch (_) {}

    final amount = double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0;
    final distKm = double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0;
    final fuelCost = _calculateJobFuelCost(r);

    final driverName = r['driverName']?.toString() ?? '-';
    final vehiclePlate = r['vehiclePlate']?.toString().trim() ?? '';
    final customerName = r['customerName']?.toString() ?? '-';
    final customerPhone = r['customerPhone']?.toString() ?? '';
    final customerAddress = r['customerAddress']?.toString() ?? '';
    final locationUrl = r['locationUrl']?.toString() ?? '';
    final note = r['note']?.toString() ?? '';
    final jobType = r['jobType']?.toString() ?? 'delivery';
    final status = r['status']?.toString() ?? '';

    final bool missingDistance = distKm == 0.0;
    final bool isDelivery = jobType == 'delivery';
    final statusColor = status == 'completed' ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: missingDistance
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Date + Status ─────────────────────────────
            Row(
              children: [
                Icon(
                  isDelivery ? Icons.local_shipping_outlined : Icons.store_mall_directory_outlined,
                  color: isDelivery ? Colors.indigo : Colors.teal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                // Missing distance warning badge
                if (missingDistance)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text('ยังไม่มีระยะทาง', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    status == 'completed' ? '✅ เสร็จสิ้น' : status,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 14),

            // ── Customer & Driver ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.person_outline, 'ลูกค้า', customerName, bold: true),
                      if (customerPhone.isNotEmpty)
                        _infoRow(Icons.phone_outlined, 'เบอร์โทร', customerPhone),
                      if (customerAddress.isNotEmpty)
                        _infoRow(Icons.location_on_outlined, 'ที่อยู่', customerAddress),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.person_search_outlined, 'คนขับ', driverName.isEmpty ? '-' : driverName),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 5),
                            Text('รถ: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      vehiclePlate.isEmpty ? 'ไม่ระบุ' : vehiclePlate,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _showAssignVehicleDialog(context, r),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.edit, size: 14, color: Colors.indigo),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Stats Row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statChip(
                    icon: Icons.payments_outlined,
                    label: 'ยอดเงิน',
                    value: '฿${_moneyFormat.format(amount)}',
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statChip(
                    icon: Icons.route_outlined,
                    label: 'ระยะทาง (จากลูกค้า)',
                    value: distKm > 0 ? '${distKm.toStringAsFixed(2)} กม.' : '— ยังไม่กำหนด',
                    color: distKm > 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statChip(
                    icon: Icons.local_gas_station_outlined,
                    label: 'ค่าน้ำมัน',
                    value: fuelCost > 0 ? '฿${_moneyFormat.format(fuelCost)}' : '-',
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),

            // ── GPS Link ──────────────────────────────────────────
            if (locationUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text('พิกัด GPS:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () async {
                        final url = Uri.parse(locationUrl);
                        if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      child: Text(
                        'เปิด Google Maps',
                        style: TextStyle(color: Colors.blue.shade700, fontSize: 13, decoration: TextDecoration.underline),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: locationUrl));
                        AlertService.show(context: context, message: 'คัดลอกลิงก์แล้ว', type: 'success');
                      },
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('คัดลอก', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Note ──────────────────────────────────────────────
            if (note.isNotEmpty && note != '-') ...[
              const SizedBox(height: 6),
              _infoRow(Icons.notes_outlined, 'หมายเหตุ', note),
            ],

            // ── Hint for missing distance ─────────────────────────
            if (missingDistance) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ยังไม่มีระยะทาง — กรุณากรอก "ระยะทางจัดส่ง" ในหน้าแก้ไขข้อมูลลูกค้า "$customerName"',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
