import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/stock_repository.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../services/alert_service.dart';

// ---------------------------------------------------------------------------
// 1. หน้าประวัติการรับเข้าสินค้า
// ---------------------------------------------------------------------------
class StockInHistoryView extends StatelessWidget {
  const StockInHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการรับเข้าสินค้า (รายบิล)')),
      body: const StockInPOHistoryList(),
    );
  }
}

class StockInPOHistoryList extends StatefulWidget {
  const StockInPOHistoryList({super.key});

  @override
  State<StockInPOHistoryList> createState() => _StockInPOHistoryListState();
}

class _StockInPOHistoryListState extends State<StockInPOHistoryList> {
  final StockRepository _repo = StockRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final offset = (_currentPage - 1) * _pageSize;
      final data = await _repo.getPurchaseOrders(
        status: 'RECEIVED',
        limit: _pageSize,
        offset: offset,
      );
      if (mounted) {
        setState(() {
          _orders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading PO history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changePage(int delta) {
    if (_currentPage + delta < 1) return;
    if (delta > 0 && _orders.length < _pageSize) return;
    setState(() {
      _currentPage += delta;
      _loadData();
    });
  }

  Future<void> _confirmDelete(int poId, String supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันลบประวัติการรับเข้า?'),
        content: Text(
            'คุณต้องการลบ(Void) บิล PO #$poId ($supplier) หรือไม่?\n\n*สต็อกสินค้าจะถูกตัดกลับ (Revert) ตามจำนวนที่รับเข้า*'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบรายการ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deletePurchaseOrder(poId);
        if (mounted) {
          AlertService.show(
            context: context,
            message: '✅ ลบรายการและคืนสต็อกเรียบร้อยแล้ว',
            type: 'success',
          );
          _loadData(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(
            context: context,
            message: '❌ เกิดข้อผิดพลาด: $e',
            type: 'error',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_orders.isEmpty) {
      return const Center(child: Text('ไม่พบประวัติการรับสินค้า'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _orders.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final po = _orders[i];
              final date = DateTime.tryParse(po['updatedAt'].toString()) ??
                  DateTime.now(); // Use updatedAt for received time
              final total = double.tryParse(po['totalAmount'].toString()) ?? 0;
              final itemCount = po['itemCount'] ?? 0;
              final supplier = po['supplierName'] ?? 'ไม่ระบุ Supplier';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.inventory_2, color: Colors.white),
                  ),
                  title: Text('PO #${po['id']} - $supplier',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'วันที่รับ: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}\nเอกสาร: ${po['documentNo']} | จำนวน: $itemCount รายการ',
                      style: TextStyle(color: Colors.grey[700])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '฿${NumberFormat('#,##0.00').format(total)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(po['id'], supplier),
                      ),
                    ],
                  ),
                  onTap: () async {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('รายละเอียด PO #${po['id']}'),
                        content: SizedBox(
                          width: 400,
                          height: 300,
                          child: FutureBuilder(
                            future: _repo.getPurchaseOrderItems(po['id']),
                            builder: (ctx, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final items =
                                  snapshot.data as List<Map<String, dynamic>>;
                              if (items.isEmpty) {
                                return const Center(
                                    child: Text('ไม่มีรายการสินค้า'));
                              }
                              return ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (ctx, i) => const Divider(),
                                itemBuilder: (ctx, i) {
                                  final item = items[i];
                                  final cost = double.tryParse(
                                          item['costPrice'].toString()) ??
                                      0;
                                  final qty = double.tryParse(
                                          item['quantity'].toString()) ??
                                      0;
                                  return ListTile(
                                    title: Text(item['productName']),
                                    subtitle: Text(
                                        'ทุน: ${NumberFormat('#,##0.00').format(cost)}'),
                                    trailing: Text(
                                      '${NumberFormat('#,##0').format(qty)} ชิ้น',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('ปิด'),
                          )
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Simple Pagination
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: _currentPage > 1 ? () => _changePage(-1) : null,
                  icon: const Icon(Icons.chevron_left)),
              Text('หน้า $_currentPage'),
              IconButton(
                  onPressed:
                      _orders.length == _pageSize ? () => _changePage(1) : null,
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
        )
      ],
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
      appBar: AppBar(title: const Text('ประวัติการปรับปรุงสต็อก (รวมกลุ่ม)')),
      body: const StockAdjustmentGroupedList(),
    );
  }
}

class StockAdjustmentGroupedList extends StatefulWidget {
  const StockAdjustmentGroupedList({super.key});

  @override
  State<StockAdjustmentGroupedList> createState() =>
      _StockAdjustmentGroupedListState();
}

class _StockAdjustmentGroupedListState
    extends State<StockAdjustmentGroupedList> {
  final StockRepository _repo = StockRepository();
  List<Map<String, dynamic>> _flatItems = [];
  List<AdjustmentGroup> _groups = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _pageSize = 100; // Fetch more to make grouping effective

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final offset = (_currentPage - 1) * _pageSize;
      final data = await _repo.getHistoryByType(
        null, // Type is handled by isAdjustment flag in repo, but explicitly passing null lets repo handle it if we pass isAdjustment: true
        isAdjustment: true,
        limit: _pageSize,
        offset: offset,
      );

      // Grouping Logic
      List<AdjustmentGroup> newGroups = [];
      if (data.isNotEmpty) {
        AdjustmentGroup? currentGroup;

        for (var item in data) {
          final DateTime itemTime =
              DateTime.tryParse(item['createdAt'].toString()) ?? DateTime.now();

          // Start new group if null or time difference > 2 minutes
          if (currentGroup == null ||
              currentGroup.startTime.difference(itemTime).abs().inMinutes > 2) {
            // Push old group
            if (currentGroup != null) {
              newGroups.add(currentGroup);
            }

            // Create new group
            currentGroup = AdjustmentGroup(
              startTime: itemTime,
              items: [item],
            );
          } else {
            // Add to current group
            currentGroup.items.add(item);
          }
        }
        // Push last group
        if (currentGroup != null) {
          newGroups.add(currentGroup);
        }
      }

      if (mounted) {
        setState(() {
          _flatItems = data;
          _groups = newGroups;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading adjustment history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changePage(int delta) {
    if (_currentPage + delta < 1) return;
    if (delta > 0 && _flatItems.length < _pageSize) return;
    setState(() {
      _currentPage += delta;
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_groups.isEmpty) {
      return const Center(child: Text('ไม่พบประวัติการปรับปรุงสต็อก'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _groups.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              return _GroupCard(
                group: _groups[i],
                onDelete: () => _confirmDeleteGroup(_groups[i]),
              );
            },
          ),
        ),
        // Simple Pagination
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: _currentPage > 1 ? () => _changePage(-1) : null,
                  icon: const Icon(Icons.chevron_left)),
              Text('หน้า $_currentPage'),
              IconButton(
                  onPressed: _flatItems.length == _pageSize
                      ? () => _changePage(1)
                      : null,
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
        )
      ],
    );
  }

  Future<void> _confirmDeleteGroup(AdjustmentGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบประวัติและคืนค่าสต็อก?'),
        content: Text(
            'คุณต้องการลบรายการปรับสต็อก ${group.totalItems} รายการนี้หรือไม่?\n\n'
            '⚠️ ระบบจะทำการ **"คืนค่าสต็อก" (Revert)** กลับเป็นค่าเดิม\n'
            '(เช่น ถ้าเคย +10 จะถูกปรับ -10 กลับคืน)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Extract IDs
        final ids =
            group.items.map((i) => int.parse(i['id'].toString())).toList();
        await _repo.deleteAdjustmentGroup(ids);

        if (mounted) {
          AlertService.show(
            context: context,
            message: '✅ ลบรายการและคืนค่าสต็อกเรียบร้อยแล้ว',
            type: 'success',
          );
          _loadData(); // Refresh
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(
            context: context,
            message: '❌ เกิดข้อผิดพลาด: $e',
            type: 'error',
          );
        }
      }
    }
  }
}

class AdjustmentGroup {
  final DateTime startTime;
  final List<Map<String, dynamic>> items;

  AdjustmentGroup({required this.startTime, required this.items});

  int get totalItems => items.length;

  // Stats
  int get matchCount => items
      .where((i) => (double.tryParse(i['quantityChange'].toString()) ?? 0) == 0)
      .length;
  int get diffCount => items
      .where((i) => (double.tryParse(i['quantityChange'].toString()) ?? 0) != 0)
      .length;
}

class _GroupCard extends StatelessWidget {
  final AdjustmentGroup group;
  final VoidCallback onDelete;

  const _GroupCard({required this.group, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.history, color: Colors.orange.shade800),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'ตรวจนับสต็อก (Check Stock)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'ลบรายการกลุ่มนี้',
            )
          ],
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(group.startTime)}\n'
          'รายการทั้งหมด: ${group.totalItems} (ตรง: ${group.matchCount}, ปรับ: ${group.diffCount})',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        children: group.items.map((item) {
          final qty = double.tryParse(item['quantityChange'].toString()) ?? 0;
          final productName =
              item['productName'] ?? 'สินค้า #${item['productId']}';
          final note = item['note'] ?? '';

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(productName),
            subtitle: Text(note, maxLines: 1),
            trailing: Text(
              qty == 0
                  ? 'OK'
                  : '${qty > 0 ? "+" : ""}${qty.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: qty == 0
                    ? Colors.green
                    : (qty > 0 ? Colors.green : Colors.red),
              ),
            ),
          );
        }).toList(),
      ),
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
                              qty == 0
                                  ? Icons.check_circle_outline
                                  : (qty > 0
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward),
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
                            qty == 0
                                ? 'OK'
                                : ((qty > 0 ? '+' : '') +
                                    qty.toStringAsFixed(0)),
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
