import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/fuel_price_repository.dart';
import '../../repositories/vehicle_settings_repository.dart';
import '../../services/alert_service.dart';

class FuelManagementScreen extends StatefulWidget {
  const FuelManagementScreen({super.key});

  @override
  State<FuelManagementScreen> createState() => _FuelManagementScreenState();
}

class _FuelManagementScreenState extends State<FuelManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FuelPriceRepository _fuelRepo = FuelPriceRepository();
  final VehicleSettingsRepository _vehicleRepo = VehicleSettingsRepository();

  bool _loadingPrices = false;
  bool _loadingVehicles = false;
  List<Map<String, dynamic>> _prices = [];
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _latestPrice;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _moneyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrices();
    _loadVehicles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Load Data ───────────────────────────────────────────────────
  Future<void> _loadPrices() async {
    setState(() => _loadingPrices = true);
    try {
      final prices = await _fuelRepo.getAllPrices();
      final latest = await _fuelRepo.getLatestPrice();
      if (mounted) {
        setState(() {
          _prices = prices;
          _latestPrice = latest;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'โหลดราคาน้ำมันไม่สำเร็จ: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  Future<void> _loadVehicles() async {
    setState(() => _loadingVehicles = true);
    try {
      final vehicles = await _vehicleRepo.getAllVehicles();
      if (mounted) setState(() => _vehicles = vehicles);
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'โหลดข้อมูลรถไม่สำเร็จ: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  // ─── Fuel Price Dialog ────────────────────────────────────────────
  Future<void> _showAddPriceDialog({Map<String, dynamic>? existing}) async {
    DateTime selectedDate = existing != null
        ? DateTime.tryParse(existing['effective_date']?.toString() ?? '') ??
            DateTime.now()
        : DateTime.now();
    final priceCtrl = TextEditingController(
      text: existing != null ? existing['price_per_liter']?.toString() : '',
    );
    final noteCtrl = TextEditingController(
      text: existing?['note']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setInner) => AlertDialog(
          title: Text(existing != null ? 'แก้ไขราคาน้ำมัน' : 'เพิ่มราคาน้ำมัน'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // วันที่มีผล
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx2,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                      builder: (ctx3, child) => Theme(
                        data: Theme.of(ctx3).copyWith(
                          dialogTheme: DialogThemeData(
                            backgroundColor: Theme.of(ctx3).colorScheme.surface,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setInner(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'วันที่มีผล',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_dateFormat.format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 12),
                // ราคา
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ราคาน้ำมันดีเซล (บาท/ลิตร)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_gas_station),
                    suffixText: 'บาท/ลิตร',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                // หมายเหตุ
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'หมายเหตุ (ไม่บังคับ)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final price = double.tryParse(priceCtrl.text.trim());
      if (price == null || price <= 0) {
        AlertService.show(
            context: context, message: 'กรุณากรอกราคาน้ำมันให้ถูกต้อง', type: 'warning');
        return;
      }
      try {
        await _fuelRepo.upsertPrice(
          date: selectedDate,
          pricePerLiter: price,
          note: noteCtrl.text.trim(),
        );
        await _loadPrices();
        if (mounted) {
          AlertService.show(
              context: context, message: 'บันทึกราคาน้ำมันสำเร็จ', type: 'success');
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
        }
      }
    }
  }

  Future<void> _deletePrice(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'ต้องการลบราคาน้ำมันวันที่ ${row['effective_date']} (${row['price_per_liter']} บาท/ลิตร) ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _fuelRepo.deletePrice(int.tryParse(row['id']?.toString() ?? '0') ?? 0);
      await _loadPrices();
    }
  }

  // ─── Vehicle Efficiency Dialog ────────────────────────────────────
  Future<void> _showVehicleDialog({Map<String, dynamic>? existing}) async {
    final plateCtrl =
        TextEditingController(text: existing?['vehicle_plate']?.toString() ?? '');
    final effCtrl = TextEditingController(
      text: existing != null
          ? existing['fuel_efficiency']?.toString()
          : VehicleSettingsRepository.defaultEfficiency.toString(),
    );
    final typeCtrl =
        TextEditingController(text: existing?['vehicle_type']?.toString() ?? '');
    final noteCtrl =
        TextEditingController(text: existing?['note']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'แก้ไขข้อมูลรถ' : 'เพิ่มรถ'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plateCtrl,
                readOnly: existing != null,
                decoration: InputDecoration(
                  labelText: 'ทะเบียนรถ',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.directions_car),
                  filled: existing != null,
                  fillColor: existing != null ? Colors.grey.shade100 : null,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: effCtrl,
                decoration: const InputDecoration(
                  labelText: 'อัตราสิ้นเปลือง',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                  suffixText: 'กม./ลิตร',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeCtrl,
                decoration: const InputDecoration(
                  labelText: 'ประเภทรถ (เช่น รถกระบะ, รถดั้ม)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final plate = plateCtrl.text.trim().toUpperCase();
      final eff = double.tryParse(effCtrl.text.trim());
      if (plate.isEmpty) {
        AlertService.show(
            context: context, message: 'กรุณากรอกทะเบียนรถ', type: 'warning');
        return;
      }
      if (eff == null || eff <= 0) {
        AlertService.show(
            context: context, message: 'กรุณากรอกอัตราสิ้นเปลืองให้ถูกต้อง', type: 'warning');
        return;
      }
      try {
        await _vehicleRepo.upsertVehicle(
          vehiclePlate: plate,
          fuelEfficiency: eff,
          vehicleType: typeCtrl.text.trim(),
          note: noteCtrl.text.trim(),
        );
        await _loadVehicles();
        if (mounted) {
          AlertService.show(
              context: context, message: 'บันทึกข้อมูลรถสำเร็จ', type: 'success');
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
        }
      }
    }
  }

  Future<void> _syncVehiclesFromHistory() async {
    try {
      final count = await _vehicleRepo.syncVehiclesFromHistory();
      await _loadVehicles();
      if (mounted) {
        AlertService.show(
            context: context,
            message: 'Sync รถจากประวัติส่งของสำเร็จ ($count คัน)',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'Sync ล้มเหลว: $e', type: 'error');
      }
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรถ ${row['vehicle_plate']} ออกจากการตั้งค่าใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _vehicleRepo.deleteVehicle(
          int.tryParse(row['id']?.toString() ?? '0') ?? 0);
      await _loadVehicles();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการน้ำมัน'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.65),
          indicatorColor: colorScheme.onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.local_gas_station), text: 'ราคาน้ำมัน'),
            Tab(icon: Icon(Icons.directions_car), text: 'ตั้งค่ารถ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPriceTab(colorScheme),
          _buildVehicleTab(colorScheme),
        ],
      ),
    );
  }

  // ─── Tab 1: ราคาน้ำมัน ───────────────────────────────────────────
  Widget _buildPriceTab(ColorScheme cs) {
    return Column(
      children: [
        // Header Banner
        Container(
          color: Colors.amber.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.local_gas_station, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ราคาน้ำมันดีเซล',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (_latestPrice != null)
                      Text(
                        'ปัจจุบัน: ${_moneyFormat.format(double.tryParse(_latestPrice!['price_per_liter']?.toString() ?? '0') ?? 0)} บาท/ลิตร '
                        '(มีผลตั้งแต่ ${_latestPrice!['effective_date']})',
                        style: const TextStyle(color: Colors.orange, fontSize: 13),
                      )
                    else
                      const Text('ยังไม่มีราคาน้ำมัน — กรุณาเพิ่มราคา',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddPriceDialog(),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มราคา'),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: _loadingPrices
              ? const Center(child: CircularProgressIndicator())
              : _prices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_gas_station,
                              size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('ยังไม่มีข้อมูลราคาน้ำมัน',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _showAddPriceDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มราคาวันนี้'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            cs.primary.withValues(alpha: 0.1)),
                        columns: const [
                          DataColumn(label: Text('วันที่มีผล')),
                          DataColumn(label: Text('ราคา (บาท/ลิตร)'), numeric: true),
                          DataColumn(label: Text('หมายเหตุ')),
                          DataColumn(label: Text('จัดการ')),
                        ],
                        rows: _prices.map((row) {
                          final isLatest = row['id'] == _latestPrice?['id'];
                          final price = double.tryParse(
                                  row['price_per_liter']?.toString() ?? '0') ??
                              0.0;
                          return DataRow(
                            color: isLatest
                                ? WidgetStateProperty.all(Colors.orange.shade50)
                                : null,
                            cells: [
                              DataCell(Row(
                                children: [
                                  if (isLatest)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.star,
                                          color: Colors.orange, size: 14),
                                    ),
                                  Text(row['effective_date']?.toString() ?? '-',
                                      style: isLatest
                                          ? const TextStyle(
                                              fontWeight: FontWeight.bold)
                                          : null),
                                ],
                              )),
                              DataCell(Text(
                                _moneyFormat.format(price),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLatest ? Colors.orange.shade800 : null,
                                ),
                              )),
                              DataCell(Text(row['note']?.toString() ?? '-')),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    tooltip: 'แก้ไข',
                                    onPressed: () =>
                                        _showAddPriceDialog(existing: row),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    tooltip: 'ลบ',
                                    onPressed: () => _deletePrice(row),
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }

  // ─── Tab 2: ตั้งค่ารถ ────────────────────────────────────────────
  Widget _buildVehicleTab(ColorScheme cs) {
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
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      'ใช้ในการคำนวณต้นทุนน้ำมัน (ลิตร = ระยะทาง ÷ กม./ลิตร)',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _syncVehiclesFromHistory,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync จากประวัติ'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showVehicleDialog(),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรถ'),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: _loadingVehicles
              ? const Center(child: CircularProgressIndicator())
              : _vehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car,
                              size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('ยังไม่มีข้อมูลรถ',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _syncVehiclesFromHistory,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync จากประวัติส่งของ'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _showVehicleDialog(),
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
                        headingRowColor: WidgetStateProperty.all(
                            cs.primary.withValues(alpha: 0.1)),
                        columns: const [
                          DataColumn(label: Text('ทะเบียนรถ')),
                          DataColumn(
                              label: Text('อัตราสิ้นเปลือง'), numeric: true),
                          DataColumn(label: Text('ประเภทรถ')),
                          DataColumn(label: Text('หมายเหตุ')),
                          DataColumn(label: Text('จัดการ')),
                        ],
                        rows: _vehicles.map((row) {
                          final eff = double.tryParse(
                                  row['fuel_efficiency']?.toString() ?? '7') ??
                              7.0;
                          return DataRow(cells: [
                            DataCell(Text(
                              row['vehicle_plate']?.toString() ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              '${_moneyFormat.format(eff)} กม./ลิตร',
                              style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600),
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
                                  onPressed: () =>
                                      _showVehicleDialog(existing: row),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  tooltip: 'ลบ',
                                  onPressed: () => _deleteVehicle(row),
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
