import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/stock_repository.dart';
import '../../widgets/common/custom_buttons.dart';

// ---------------------------------------------------------------------------
// 1. หน้าประวัติการรับเข้าสินค้า
// ---------------------------------------------------------------------------
class StockInHistoryView extends StatelessWidget {
  const StockInHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการรับเข้าสินค้า')),
      body: const GenericStockHistoryList(transactionType: 'PURCHASE_IN'),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. หน้าประวัติการปรับปรุงสต็อก
// ---------------------------------------------------------------------------
class StockAdjustmentHistoryView extends StatelessWidget {
  const StockAdjustmentHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการปรับปรุงสต็อก')),
      body: const GenericStockHistoryList(filterAdjust: true),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. หน้าประวัติการรับคืนสินค้า
// ---------------------------------------------------------------------------
class StockHistoryView extends StatelessWidget {
  const StockHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการรับคืนสินค้า')),
      body: const GenericStockHistoryList(transactionType: 'RETURN_IN'),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget กลางสำหรับแสดงรายการ (เพิ่ม DatePicker + Pagination)
// ---------------------------------------------------------------------------
class GenericStockHistoryList extends StatefulWidget {
  final String? transactionType;
  final bool filterAdjust;

  const GenericStockHistoryList({
    super.key,
    this.transactionType,
    this.filterAdjust = false,
  });

  @override
  State<GenericStockHistoryList> createState() =>
      _GenericStockHistoryListState();
}

class _GenericStockHistoryListState extends State<GenericStockHistoryList> {
  final StockRepository _stockRepo = StockRepository();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  // ✨ ตัวแปรใหม่สำหรับ Pagination และ Date Filter
  DateTimeRange? _dateRange;
  int _currentPage = 1;
  final int _pageSize = 20; // โชว์ทีละ 20 รายการ
  bool _hasMore = true; // เช็คว่ามีหน้าถัดไปไหม

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final offset = (_currentPage - 1) * _pageSize;

      final data = await _stockRepo.getHistoryByType(
        widget.transactionType,
        isAdjustment: widget.filterAdjust,
        limit: _pageSize,
        offset: offset,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      if (mounted) {
        setState(() {
          _items = data;
          _isLoading = false;
          // ถ้าดึงมาได้น้อยกว่า pageSize แสดงว่าหมดแล้ว
          _hasMore = data.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _currentPage = 1; // รีเซ็ตไปหน้าแรกเมื่อเปลี่ยนตัวกรอง
      });
      _loadData();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateRange = null;
      _currentPage = 1;
    });
    _loadData();
  }

  void _changePage(int newPage) {
    if (newPage < 1) return;
    setState(() {
      _currentPage = newPage;
    });
    _loadData();
  }

  Color _getTypeColor(String type) {
    if (type.contains('IN') || type.contains('ADD')) return Colors.green;
    if (type.contains('OUT') || type.contains('SUB')) return Colors.red;
    return Colors.grey;
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'PURCHASE_IN':
        return 'รับเข้า (ซื้อ)';
      case 'SALE_OUT':
        return 'ขายออก';
      case 'ADJUST_ADD':
        return 'ปรับเพิ่ม';
      case 'ADJUST_SUB':
        return 'ปรับลด';
      case 'ADJUST_FIX':
        return 'ปรับยอด (Count)';
      case 'RETURN_IN':
        return 'รับคืน';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔹 1. ส่วนหัวเลือกวันที่ (Date Picker Header)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateRange == null
                      ? 'แสดงทั้งหมด (ล่าสุด)'
                      : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _clearDateFilter,
                  tooltip: 'ล้างตัวกรอง',
                ),
              CustomButton(
                onPressed: _pickDateRange,
                label: 'เลือกช่วงเวลา',
                type: ButtonType.primary,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 🔹 2. รายการสินค้า (List Content)
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('ไม่พบประวัติรายการ',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        final date =
                            DateTime.tryParse(item['createdAt'].toString()) ??
                                DateTime.now();
                        final qty = double.tryParse(
                                item['quantityChange'].toString()) ??
                            0;
                        final type = item['transactionType'].toString();
                        final productName = item['productName'] ??
                            'สินค้า #${item['productId']}';
                        final note = item['note'] ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getTypeColor(type).withValues(alpha: 0.1),
                            child: Icon(
                              qty >= 0
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: _getTypeColor(type),
                              size: 20,
                            ),
                          ),
                          title: Text(productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${_getTypeLabel(type)} | ${DateFormat('dd/MM/yyyy HH:mm').format(date)}\n$note',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            (qty > 0 ? '+' : '') + qty.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _getTypeColor(type),
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // 🔹 3. ตัวเปลี่ยนหน้า (Pagination Footer)
        if (_items.isNotEmpty || _currentPage > 1)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => _changePage(_currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('หน้า $_currentPage',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed:
                      _hasMore ? () => _changePage(_currentPage + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
