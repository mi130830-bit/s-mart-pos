import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/alert_service.dart';
import '../../../../models/supplier.dart';
import '../../../../repositories/stock_repository.dart';
import '../../../../widgets/common/custom_buttons.dart';
import '../../widgets/supplier_search_dialog.dart';
import '../dialogs/edit_received_qty_dialog.dart';
import '../pages/stock_in_create_page.dart';

class PurchaseOrderHistoryTab extends StatefulWidget {
  const PurchaseOrderHistoryTab({super.key});

  @override
  State<PurchaseOrderHistoryTab> createState() => _PurchaseOrderHistoryTabState();
}

class _PurchaseOrderHistoryTabState extends State<PurchaseOrderHistoryTab> {
  final StockRepository _stockRepo = StockRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  // Filters
  DateTime? _selectedDate;
  int? _selectedSupplierId;
  String? _selectedSupplierName;
  String _paymentFilter = 'ALL';

  // Pagination
  int _currentPage = 1;
  final int _limit = 25;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _pickSupplier() async {
    final Supplier? selected = await showDialog<Supplier>(
      context: context,
      builder: (context) => const SupplierSearchDialog(),
    );
    if (selected != null) {
      if (selected.id == _selectedSupplierId) return;
      setState(() {
        _selectedSupplierId = selected.id;
        _selectedSupplierName = selected.name;
        _currentPage = 1;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      DateTime? startDate;
      DateTime? endDate;
      if (_selectedDate != null) {
        startDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
        endDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
      }
      bool? isPaidFilter;
      if (_paymentFilter == 'UNPAID') isPaidFilter = false;
      if (_paymentFilter == 'PAID') isPaidFilter = true;

      final received = await _stockRepo.getPurchaseOrders(
        status: 'RECEIVED',
        startDate: startDate,
        endDate: endDate,
        supplierId: _selectedSupplierId,
        isPaid: isPaidFilter,
        limit: _limit + 1,
        offset: (_currentPage - 1) * _limit,
      );
      bool hasNext = false;
      if (received.length > _limit) {
        hasNext = true;
        received.removeLast();
      }
      if (mounted) {
        setState(() {
          _orders = received;
          _orders.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
          _hasNextPage = hasNext;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 1;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final displayOrders = _orders;

    return Column(
      children: [
        // 🔎 Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate == null
                    ? 'ทุกวัน (All Time)'
                    : 'วันที่: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'ล้างวันที่',
                  onPressed: () {
                    setState(() { _selectedDate = null; _currentPage = 1; });
                    _loadData();
                  },
                ),
              ],
              const SizedBox(width: 16),
              const VerticalDivider(),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSupplier,
                  icon: const Icon(Icons.store),
                  label: Text(
                    _selectedSupplierId == null ? 'ผู้ขาย: ทั้งหมด (All Suppliers)' : 'ผู้ขาย: $_selectedSupplierName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              if (_selectedSupplierId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'ล้างผู้ขาย',
                  onPressed: () {
                    setState(() { _selectedSupplierId = null; _selectedSupplierName = null; _currentPage = 1; });
                    _loadData();
                  },
                ),
              ],
              const SizedBox(width: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _paymentFilter,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('สถานะการเงิน: ทั้งหมด')),
                      DropdownMenuItem(value: 'UNPAID', child: Text('⚠️ ค้างจ่าย', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'PAID', child: Text('✅ จ่ายแล้ว', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) {
                      if (val != null && val != _paymentFilter) {
                        setState(() { _paymentFilter = val; _currentPage = 1; });
                        _loadData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        if (displayOrders.isEmpty) ...[
          const SizedBox(height: 50),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('ไม่พบประวัติการรับเข้าตามเงื่อนไข', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        ] else ...[
          // Table Header
          Container(
            color: Colors.indigo,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('วันที่', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('เลขที่เอกสาร', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('ผู้ขาย', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('รายการ', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('จ่ายเงิน', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('ยอดรวม', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(width: 96),
              ],
            ),
          ),
          // List Body
          Expanded(
            child: ListView.builder(
              itemCount: displayOrders.length,
              itemBuilder: (ctx, i) {
                final order = displayOrders[i];
                final dt = DateTime.parse(order['createdAt'].toString());
                bool isNewMonth = false;
                if (i == 0) {
                  isNewMonth = true;
                } else {
                  final prevDt = DateTime.parse(displayOrders[i - 1]['createdAt'].toString());
                  if (dt.month != prevDt.month || dt.year != prevDt.year) isNewMonth = true;
                }

                final itemWidget = InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('รายละเอียดใบรับเข้า #${order['documentNo'] ?? order['id']}')),
                          body: StockInCreatePage(existingPoId: int.tryParse(order['id'].toString())),
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                  child: Container(
                    color: i % 2 == 0 ? Colors.white : Colors.indigo.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 50, child: Text('${i + 1}', style: const TextStyle(color: Colors.grey))),
                        Expanded(
                          flex: 2,
                          child: Builder(builder: (context) {
                            final updatedAtRaw = order['updatedAt'];
                            final createdAtRaw = order['createdAt'];
                            bool isModified = false;
                            String modifiedDateStr = '';
                            if (updatedAtRaw != null && createdAtRaw != null) {
                              try {
                                final updatedAt = DateTime.parse(updatedAtRaw.toString());
                                final createdAt = DateTime.parse(createdAtRaw.toString());
                                isModified = updatedAt.difference(createdAt).inSeconds.abs() >= 2;
                                if (isModified) modifiedDateStr = DateFormat('dd/MM/yy HH:mm').format(updatedAt);
                              } catch (_) {}
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(DateFormat('dd/MM/yyyy HH:mm').format(dt)),
                                if (isModified)
                                  Tooltip(
                                    message: 'แก้ไขล่าสุด: $modifiedDateStr',
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        border: Border.all(color: Colors.orange.shade400, width: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit, size: 10, color: Colors.orange.shade700),
                                          const SizedBox(width: 3),
                                          Text('ถูกแก้ไข', style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ),
                        Expanded(flex: 2, child: Text(order['documentNo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 3, child: Text(order['supplierName'] ?? 'ไม่ระบุ')),
                        Expanded(flex: 1, child: Text('${order['itemCount']}', textAlign: TextAlign.center)),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: InkWell(
                              onTap: () => _togglePaymentStatus(order),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (int.tryParse(order['isPaid'].toString()) ?? 0) == 1
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (int.tryParse(order['isPaid'].toString()) ?? 0) == 1 ? Colors.green : Colors.red,
                                  ),
                                ),
                                child: Text(
                                  (int.tryParse(order['isPaid'].toString()) ?? 0) == 1 ? 'จ่ายแล้ว' : 'ค้างจ่าย',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (int.tryParse(order['isPaid'].toString()) ?? 0) == 1 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            NumberFormat('#,##0.00').format(double.tryParse(order['totalAmount'].toString()) ?? 0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.indigo, size: 20),
                            onPressed: () => _editReceivedOrder(order),
                            tooltip: 'แก้ไขจำนวน',
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _deleteOrder(order),
                            tooltip: 'ลบและคืนสต็อก',
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (isNewMonth) {
                  final monthYearLabel = '${DateFormat('MMMM', 'th').format(dt)} ${dt.year + 543}';
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (i > 0) const Divider(height: 1, thickness: 2),
                      Container(
                        color: Colors.indigo.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(monthYearLabel,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade800)),
                      ),
                      itemWidget,
                    ],
                  );
                }
                return Column(mainAxisSize: MainAxisSize.min, children: [const Divider(height: 1), itemWidget]);
              },
            ),
          ),
          // Summary Footer
          if (_orders.isNotEmpty) ...[
            Builder(builder: (context) {
              final totalAll = _orders.fold<double>(0, (s, o) => s + (double.tryParse(o['totalAmount']?.toString() ?? '0') ?? 0));
              final totalUnpaid = _orders.where((o) => (int.tryParse(o['isPaid']?.toString() ?? '0') ?? 0) == 0).fold<double>(0, (s, o) => s + (double.tryParse(o['totalAmount']?.toString() ?? '0') ?? 0));
              final totalPaid = totalAll - totalUnpaid;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.indigo.shade50, border: Border(top: BorderSide(color: Colors.indigo.shade100, width: 2))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade300)),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        const Text('ค้างจ่าย: ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Text('฿${NumberFormat('#,##0.00').format(totalUnpaid)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade300)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        const Text('จ่ายแล้ว: ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Text('฿${NumberFormat('#,##0.00').format(totalPaid)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ),
                    const Spacer(),
                    const Text('รวมยอดสุทธิ: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Text('฿${NumberFormat('#,##0.00').format(totalAll)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(width: 96),
                  ],
                ),
              );
            }),
          ],
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _currentPage > 1 ? () { setState(() => _currentPage--); _loadData(); } : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('หน้าก่อนหน้า'),
                ),
                const SizedBox(width: 16),
                Text('หน้า $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _hasNextPage ? () { setState(() => _currentPage++); _loadData(); } : null,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('หน้าถัดไป'), SizedBox(width: 8), Icon(Icons.chevron_right)]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editReceivedOrder(Map<String, dynamic> order) async {
    final poId = int.tryParse(order['id'].toString()) ?? 0;
    if (poId == 0) return;
    List<Map<String, dynamic>> items = [];
    try {
      items = await _stockRepo.getPurchaseOrderItems(poId);
    } catch (e) {
      if (!mounted) return;
      AlertService.show(context: context, message: 'ไม่สามารถโหลดรายการสินค้าได้: $e', type: 'error');
      return;
    }
    if (!mounted) return;
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => EditReceivedQtyDialog(
        poId: poId,
        orderRef: order['documentNo']?.toString() ?? '#$poId',
        items: items,
        vatType: int.tryParse(order['vatType']?.toString() ?? '0') ?? 0,
      ),
    );
    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final vatType = int.tryParse(order['vatType']?.toString() ?? '0') ?? 0;
      double subtotal = result.fold(0.0, (s, item) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        return s + (qty * cost);
      });
      double totalWithVat = subtotal;
      if (vatType == 1) totalWithVat = subtotal * 1.07;
      await _stockRepo.updateReceivedPurchaseOrderQty(
        poId: poId,
        newItems: result,
        totalAmount: totalWithVat,
        documentNo: order['documentNo']?.toString(),
        vatType: vatType,
        isPaid: (int.tryParse(order['isPaid']?.toString() ?? '0') ?? 0) == 1,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _loadData();
      AlertService.show(context: context, message: 'แก้ไขรายการรับเข้าเรียบร้อยแล้ว', type: 'success');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      AlertService.show(context: context, message: 'เกิดข้อผิดพลาดในการแก้ไข: $e', type: 'error');
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบใบรับเข้า #${order['documentNo'] ?? order['id']} และคืนสต็อกใช่หรือไม่?'),
        actions: [
          CustomButton(label: 'ยกเลิก', type: ButtonType.secondary, onPressed: () => Navigator.pop(ctx, false)),
          CustomButton(label: 'ยืนยันลบ', backgroundColor: Colors.red, foregroundColor: Colors.white, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        await _stockRepo.deletePurchaseOrder(int.tryParse(order['id'].toString()) ?? 0);
        if (!mounted) return;
        Navigator.pop(context);
        _loadData();
        AlertService.show(context: context, message: 'ลบรายการสั่งซื้อเรียบร้อยแล้ว', type: 'success');
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาดในการลบ: $e', type: 'error');
      }
    }
  }

  Future<void> _togglePaymentStatus(Map<String, dynamic> order) async {
    final poId = int.tryParse(order['id'].toString()) ?? 0;
    if (poId == 0) return;
    final currentStatus = (int.tryParse(order['isPaid']?.toString() ?? '0') ?? 0) == 1;
    final newStatus = !currentStatus;
    try {
      await _stockRepo.updatePaymentStatus(poId, newStatus);
      setState(() => order['isPaid'] = newStatus ? 1 : 0);
      if (mounted) {
        AlertService.show(
          context: context,
          message: newStatus ? '✅ ทำเครื่องหมาย "จ่ายแล้ว" เรียบร้อย' : '⚠️ ทำเครื่องหมาย "ค้างจ่าย" เรียบร้อย',
          type: newStatus ? 'success' : 'warning',
        );
      }
    } catch (e) {
      if (mounted) AlertService.show(context: context, message: 'ไม่สามารถอัปเดตสถานะได้: $e', type: 'error');
    }
  }
}
