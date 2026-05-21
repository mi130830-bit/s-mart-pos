import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/mysql_service.dart';
import '../../services/alert_service.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../../repositories/sales_repository.dart';
import '../../models/order_item.dart';
import 'delivery_coordinator.dart';

import 'widgets/delivery_dashboard/delivery_map_marker.dart';
import 'widgets/delivery_dashboard/delivery_map_view.dart';
import 'widgets/delivery_dashboard/delivery_summary_cards.dart';
import 'widgets/delivery_dashboard/delivery_search_filter_bar.dart';
import 'widgets/delivery_dashboard/delivery_records_table.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  final DeliveryIntegrationService? deliveryService;
  const DeliveryDashboardScreen({super.key, this.deliveryService});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final DeliveryCoordinator _coordinator = DeliveryCoordinator();

  bool _isLoading = false;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _records = [];
  Map<String, double> _priceLookup = {};
  Map<String, double> _efficiencyMap = {};
  List<Map<String, dynamic>> _allVehicles = [];

  String? _selectedVehicle;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _coordinator.loadDashboardData(_startDate, _endDate);
      if (mounted) {
        setState(() {
          _records = data.records;
          _priceLookup = data.priceLookup;
          _efficiencyMap = data.efficiencyMap;
          _allVehicles = data.vehicles;
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
        fuelPrice = DeliveryCoordinator.resolvePriceFromLookup(_priceLookup, dt);
      } catch (_) {}
    }

    final eff = _efficiencyMap[plate] ?? DeliveryCoordinator.defaultEfficiency;
    final liters = dist / eff;
    return liters * fuelPrice;
  }

  double get _totalDistance => _filteredRecords.fold(0.0, (s, r) => s + (double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0));
  double get _totalAmount => _filteredRecords.fold(0.0, (s, r) => s + (double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0));
  double get _totalFuelCost => _filteredRecords.fold(0.0, (s, r) => s + _calculateJobFuelCost(r));
  int get _missingDistanceCount => _filteredRecords.where((r) => (double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0) == 0.0).length;

  Future<void> _showOrderDetail(int orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final result = await SalesRepository().getOrderWithItems(orderId);
    if (!mounted) return;
    Navigator.pop(context); // ปิด Loading

    if (result == null) {
      AlertService.show(context: context, message: 'ไม่พบบิลเลขที่ $orderId', type: 'error');
      return;
    }

    final items = result['items'] as List<OrderItem>;
    final order = result['order'];
    final dt = DateTime.parse(order['createdAt'].toString());
    final moneyFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายละเอียดบิล #$orderId\n${dateFormat.format(dt)}',
            textAlign: TextAlign.center),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                          '${item.quantity} x ${moneyFormat.format(item.price.toDouble())}'),
                      trailing: Text(
                        moneyFormat.format(item.total.toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
              onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
        ],
      ),
    );
  }

  List<DeliveryMapMarker> get _mapMarkers {
    final List<DeliveryMapMarker> list = [];
    for (int i = 0; i < _filteredRecords.length; i++) {
      final r = _filteredRecords[i];
      final locationUrl = r['locationUrl']?.toString() ?? '';
      final customerName = r['customerName']?.toString() ?? 'ลูกค้า';
      final orderId = r['orderId']?.toString() ?? '';
      final driverName = r['driverName']?.toString() ?? '';

      // Try to parse coordinates from google maps url (e.g. ?q=lat,lng)
      double lat = 13.7563;
      double lng = 100.5018;
      bool hasCoords = false;

      if (locationUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(locationUrl);
          final q = uri.queryParameters['q'];
          if (q != null && q.contains(',')) {
            final parts = q.split(',');
            lat = double.parse(parts[0].trim());
            lng = double.parse(parts[1].trim());
            hasCoords = true;
          }
        } catch (_) {}
      }

      if (hasCoords) {
        list.add(DeliveryMapMarker(
          id: 'marker_${r['id'] ?? i}',
          latitude: lat,
          longitude: lng,
          title: customerName,
          snippet: 'บิล #$orderId | คนขับ: $driverName',
        ));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_sync_outlined, size: 18),
                label: Text(_isSyncing ? 'กำลัง Sync...' : 'ดึงข้อมูลจาก Cloud'),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Map View ──
          DeliveryMapView(
            markers: _mapMarkers,
            onMarkerTap: (marker) async {
              final matchedRecord = _filteredRecords.firstWhere(
                (r) =>
                    'marker_${r['id'] ?? ''}' == marker.id ||
                    _filteredRecords.indexOf(r).toString() ==
                        marker.id.replaceAll('marker_', ''),
                orElse: () => {},
              );
              final urlStr = matchedRecord['locationUrl']?.toString() ?? '';
              if (urlStr.isNotEmpty) {
                final url = Uri.parse(urlStr);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),

          // ── Date & Vehicle Filter Bar ──
          DeliverySearchFilterBar(
            startDate: _startDate,
            endDate: _endDate,
            selectedVehicle: _selectedVehicle,
            countByVehicle: _countByVehicle,
            allVehicles: _allVehicles,
            onPickStartDate: () => _pickDate(isStart: true),
            onPickEndDate: () => _pickDate(isStart: false),
            onVehicleSelected: (vehicle) =>
                setState(() => _selectedVehicle = vehicle),
          ),

          // ── Summary Cards ──
          if (!_isLoading)
            DeliverySummaryCards(
              totalJobs: _filteredRecords.length,
              totalDistance: _totalDistance,
              totalAmount: _totalAmount,
              totalFuelCost: _totalFuelCost,
              missingDistanceCount: _missingDistanceCount,
            ),

          // ── Job Cards / Records Table ──
          Expanded(
            child: DeliveryRecordsTable(
              records: _filteredRecords,
              isLoading: _isLoading,
              onChangeDateRange: () => _pickDate(isStart: true),
              onAssignVehicle: (record) =>
                  _showAssignVehicleDialog(context, record),
              onViewOrderDetails: (orderId) => _showOrderDetail(orderId),
              onCalculateFuelCost: (record) => _calculateJobFuelCost(record),
            ),
          ),
        ],
      ),
    );
  }
}
