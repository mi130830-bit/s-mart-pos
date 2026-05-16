import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/delivery_history_repository.dart';
import '../../repositories/fuel_price_repository.dart';
import '../../repositories/vehicle_settings_repository.dart';
import '../../services/alert_service.dart';

class FuelSummaryScreen extends StatefulWidget {
  const FuelSummaryScreen({super.key});

  @override
  State<FuelSummaryScreen> createState() => _FuelSummaryScreenState();
}

class _FuelSummaryScreenState extends State<FuelSummaryScreen> {
  final DeliveryHistoryRepository _historyRepo = DeliveryHistoryRepository();
  final FuelPriceRepository _fuelRepo = FuelPriceRepository();
  final VehicleSettingsRepository _vehicleRepo = VehicleSettingsRepository();

  bool _isLoading = false;

  // ── Selected Month ─────────────────────────────────────────────────
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // ── Computed Data ──────────────────────────────────────────────────
  List<_VehicleFuelSummary> _summaries = [];
  double _totalLiters = 0;
  double _totalCost = 0;
  double _totalDistance = 0;

  final _moneyFormat = NumberFormat('#,##0.00');
  final _litersFormat = NumberFormat('#,##0.0');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _startDate => DateTime(_selectedYear, _selectedMonth, 1);
  DateTime get _endDate => DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

  // ─── Load & Compute ──────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // โหลดข้อมูลคู่ขนาน
      final results = await Future.wait([
        _historyRepo.getHistoryByDateRange(_startDate, _endDate),
        _fuelRepo.buildPriceLookup(_startDate, _endDate),
        _vehicleRepo.getEfficiencyMap(),
      ]);

      final records = results[0] as List<Map<String, dynamic>>;
      final priceLookup = results[1] as Map<String, double>;
      final efficiencyMap = results[2] as Map<String, double>;

      // Group by vehicle
      final Map<String, _VehicleFuelSummary> byVehicle = {};

      for (final r in records) {
        final dist = double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0;
        if (dist <= 0) continue; // ข้ามถ้าไม่มีระยะทาง

        // normalize plate
        final rawPlate = r['vehiclePlate']?.toString().trim().toUpperCase() ?? '';
        final plate = rawPlate.isEmpty ? 'ไม่ระบุรถ' : rawPlate;

        // ราคาน้ำมัน ณ วันส่ง
        double fuelPrice = 0.0;
        final rawDate = r['completedAt']?.toString() ?? '';
        if (rawDate.isNotEmpty) {
          try {
            final deliveryDate = DateTime.parse(rawDate);
            fuelPrice = FuelPriceRepository.resolvePriceFromLookup(
                priceLookup, deliveryDate);
          } catch (_) {}
        }

        // อัตราสิ้นเปลือง
        final efficiency = efficiencyMap[plate] ??
            VehicleSettingsRepository.defaultEfficiency;

        // คำนวณ
        final liters = dist / efficiency;
        final cost = liters * fuelPrice;

        final summary = byVehicle.putIfAbsent(
          plate,
          () => _VehicleFuelSummary(
            vehiclePlate: plate,
            efficiency: efficiency,
          ),
        );
        summary.trips++;
        summary.totalDistanceKm += dist;
        summary.totalLiters += liters;
        summary.totalCost += cost;
        if (fuelPrice > 0) {
          summary.priceSum += fuelPrice;
          summary.priceCount++;
        }
      }

      final summaries = byVehicle.values.toList()
        ..sort((a, b) => b.totalCost.compareTo(a.totalCost));

      double totalLiters = 0, totalCost = 0, totalDist = 0;
      for (final s in summaries) {
        totalLiters += s.totalLiters;
        totalCost += s.totalCost;
        totalDist += s.totalDistanceKm;
      }

      if (mounted) {
        setState(() {
          _summaries = summaries;
          _totalLiters = totalLiters;
          _totalCost = totalCost;
          _totalDistance = totalDist;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'โหลดข้อมูลไม่สำเร็จ: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Month Picker ─────────────────────────────────────────────────
  Future<void> _pickMonth() async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setInner) => AlertDialog(
          title: const Text('เลือกเดือน'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setInner(() => tempYear--),
                    ),
                    Text('พ.ศ. ${tempYear + 543}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        if (tempYear < DateTime.now().year) {
                          setInner(() => tempYear++);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Month grid
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.6,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final isSelected = m == tempMonth && tempYear == _selectedYear;
                    final isFuture = DateTime(tempYear, m).isAfter(DateTime.now());
                    return InkWell(
                      onTap: isFuture ? null : () => setInner(() => tempMonth = m),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(ctx2).colorScheme.primary
                              : isFuture
                                  ? Colors.grey.shade100
                                  : null,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(ctx2).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _monthNames[i],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isFuture
                                    ? Colors.grey
                                    : null,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ตกลง')),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _selectedYear = tempYear;
        _selectedMonth = tempMonth;
      });
      await _loadData();
    }
  }

  static const _monthNames = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabel =
        '${_monthNames[_selectedMonth - 1]} ${_selectedYear + 543}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปต้นทุนน้ำมันรายเดือน'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickMonth,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onPrimary,
                side: BorderSide(color: cs.onPrimary.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(monthLabel),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Summary Cards ────────────────────────────────────────
                Container(
                  color: cs.surfaceContainerHighest,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _summaryCard(
                        label: 'ระยะทางรวม',
                        value: '${_moneyFormat.format(_totalDistance)} กม.',
                        icon: Icons.route,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _summaryCard(
                        label: 'น้ำมันรวม',
                        value: '${_litersFormat.format(_totalLiters)} ลิตร',
                        icon: Icons.local_gas_station,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _summaryCard(
                        label: 'ต้นทุนรวม',
                        value: '฿${_moneyFormat.format(_totalCost)}',
                        icon: Icons.attach_money,
                        color: Colors.red,
                        large: true,
                      ),
                    ],
                  ),
                ),

                // ── Data Table ────────────────────────────────────────────
                Expanded(
                  child: _summaries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_gas_station,
                                  size: 72, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'ไม่มีข้อมูลการส่งของในเดือน $monthLabel',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'หรืออาจไม่มีข้อมูลระยะทาง (distanceKm = 0)',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _pickMonth,
                                icon: const Icon(Icons.calendar_month),
                                label: const Text('เปลี่ยนเดือน'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                  cs.primary.withValues(alpha: 0.1)),
                              columns: const [
                                DataColumn(label: Text('ทะเบียนรถ')),
                                DataColumn(
                                    label: Text('จำนวนงาน'), numeric: true),
                                DataColumn(
                                    label: Text('ระยะทาง (กม.)'), numeric: true),
                                DataColumn(
                                    label: Text('อัตราสิ้นเปลือง'),
                                    numeric: true),
                                DataColumn(
                                    label: Text('น้ำมัน (ลิตร)'), numeric: true),
                                DataColumn(
                                    label: Text('ราคาเฉลี่ย/ลิตร'),
                                    numeric: true),
                                DataColumn(
                                    label: Text('ต้นทุนน้ำมัน (฿)'),
                                    numeric: true),
                              ],
                              rows: [
                                // Data rows
                                ..._summaries.map((s) {
                                  final avgPrice = s.priceCount > 0
                                      ? s.priceSum / s.priceCount
                                      : 0.0;
                                  return DataRow(cells: [
                                    DataCell(Text(
                                      s.vehiclePlate,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )),
                                    DataCell(Text('${s.trips}')),
                                    DataCell(Text(
                                        _moneyFormat.format(s.totalDistanceKm))),
                                    DataCell(Text(
                                        '${_moneyFormat.format(s.efficiency)} กม./ล')),
                                    DataCell(Text(
                                        _litersFormat.format(s.totalLiters))),
                                    DataCell(Text(
                                      avgPrice > 0
                                          ? _moneyFormat.format(avgPrice)
                                          : '—',
                                      style: TextStyle(
                                          color: Colors.orange.shade700),
                                    )),
                                    DataCell(Text(
                                      '฿${_moneyFormat.format(s.totalCost)}',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold),
                                    )),
                                  ]);
                                }),
                                // Summary row
                                DataRow(
                                  color: WidgetStateProperty.all(
                                      cs.primary.withValues(alpha: 0.15)),
                                  cells: [
                                    const DataCell(Text('รวมทุกคัน',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                    DataCell(Text(
                                        '${_summaries.fold(0, (s, r) => s + r.trips)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))),
                                    DataCell(Text(
                                        _moneyFormat.format(_totalDistance),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))),
                                    const DataCell(Text('—')),
                                    DataCell(Text(
                                        _litersFormat.format(_totalLiters),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))),
                                    const DataCell(Text('—')),
                                    DataCell(Text(
                                      '฿${_moneyFormat.format(_totalCost)}',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool large = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: color, fontSize: 12)),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: large ? 18 : 15,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data Model ────────────────────────────────────────────────────
class _VehicleFuelSummary {
  final String vehiclePlate;
  final double efficiency; // กม./ลิตร
  int trips = 0;
  double totalDistanceKm = 0;
  double totalLiters = 0;
  double totalCost = 0;
  double priceSum = 0;
  int priceCount = 0;

  _VehicleFuelSummary({
    required this.vehiclePlate,
    required this.efficiency,
  });
}
