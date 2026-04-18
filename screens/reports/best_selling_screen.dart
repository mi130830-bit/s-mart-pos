import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/sales_repository.dart';
import '../../utils/date_range_helper.dart';

class BestSellingScreen extends StatefulWidget {
  final bool isEmbedded;
  const BestSellingScreen({super.key, this.isEmbedded = false});

  @override
  State<BestSellingScreen> createState() => _BestSellingScreenState();
}

class _BestSellingScreenState extends State<BestSellingScreen> {
  final SalesRepository _salesRepo = SalesRepository();
  DateRangeType _selectedRangeType = DateRangeType.today;
  DateTimeRange _currentRange =
      DateRangeHelper.getDateRange(DateRangeType.today);

  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;

  // Stats
  double _totalSalesInPeriod = 0.0;
  double _totalQtyInPeriod = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch TOP 100 for report
      final result = await _salesRepo.getTopProductsByDateRange(
          _currentRange.start, _currentRange.end,
          limit: 100);

      double totalSales = 0;
      double totalQty = 0;
      for (var item in result) {
        totalSales += double.tryParse(item['totalSales'].toString()) ?? 0.0;
        totalQty += double.tryParse(item['qty'].toString()) ?? 0.0;
      }

      setState(() {
        _data = result;
        _totalSalesInPeriod = totalSales;
        _totalQtyInPeriod = totalQty;
      });
    } catch (e) {
      debugPrint('Error loading best sellers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onRangeTypeChanged(DateRangeType? value) async {
    if (value == null) return;

    if (value == DateRangeType.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDateRange: _currentRange,
      );
      if (picked != null) {
        setState(() {
          _selectedRangeType = value;
          // Set end date to end of day
          _currentRange = DateTimeRange(
              start: picked.start,
              end: DateTime(picked.end.year, picked.end.month, picked.end.day,
                  23, 59, 59));
        });
        _loadData();
      }
    } else {
      setState(() {
        _selectedRangeType = value;
        _currentRange = DateRangeHelper.getDateRange(value);
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,##0.00", "th_TH");
    final qtyFormat = NumberFormat("#,##0.##", "th_TH");

    final content = Column(
      children: [
        // 1. Controls Area
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text('ช่วงเวลา:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              DropdownButton<DateRangeType>(
                value: _selectedRangeType,
                items: DateRangeType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(DateRangeHelper.getLabel(type)),
                  );
                }).toList(),
                onChanged: _onRangeTypeChanged,
              ),
              const SizedBox(width: 20),
              Text(
                '${DateFormat('dd/MM/yyyy').format(_currentRange.start)} - ${DateFormat('dd/MM/yyyy').format(_currentRange.end)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (widget.isEmbedded) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                  tooltip: 'รีเฟรชข้อมูล',
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. Summary Cards
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                  child: _buildSummaryCard(
                      'ยอดขายรวม (บาท)',
                      currencyFormat.format(_totalSalesInPeriod),
                      Colors.green)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSummaryCard('จำนวนที่ขายได้ (หน่วย)',
                      qtyFormat.format(_totalQtyInPeriod), Colors.blue)),
            ],
          ),
        ),

        // 3. Data Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _data.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลการขายในช่วงเวลานี้'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor:
                                WidgetStateProperty.all(Colors.grey[100]),
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('สินค้า')),
                              DataColumn(
                                  label: Text('จำนวนที่ขาย',
                                      textAlign: TextAlign.right),
                                  numeric: true),
                              DataColumn(
                                  label: Text('ยอดขาย (บาท)',
                                      textAlign: TextAlign.right),
                                  numeric: true),
                            ],
                            rows: List.generate(_data.length, (index) {
                              final item = _data[index];
                              final name = item['name'] ?? '-';
                              final qty =
                                  double.tryParse(item['qty'].toString()) ?? 0;
                              final sales = double.tryParse(
                                      item['totalSales'].toString()) ??
                                  0;

                              return DataRow(cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                                DataCell(Text(qtyFormat.format(qty))),
                                DataCell(Text(currencyFormat.format(sales))),
                              ]);
                            }),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานสินค้าขายดี (Best Sellers)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: content,
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
