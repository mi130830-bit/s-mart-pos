import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/alert_service.dart';
import '../../../../repositories/stock_repository.dart';
import '../../../../widgets/common/confirm_dialog.dart';
import '../pages/stock_in_create_page.dart';

class PurchaseOrderListTab extends StatefulWidget {
  final VoidCallback? onRefresh;
  const PurchaseOrderListTab({super.key, this.onRefresh});

  @override
  State<PurchaseOrderListTab> createState() => _PurchaseOrderListTabState();
}

class _PurchaseOrderListTabState extends State<PurchaseOrderListTab> {
  final StockRepository _stockRepo = StockRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final drafts = await _stockRepo.getPurchaseOrders(status: 'DRAFT');
      final ordered = await _stockRepo.getPurchaseOrders(status: 'ORDERED');
      final partial = await _stockRepo.getPurchaseOrders(status: 'PARTIAL');
      setState(() {
        _orders = [...drafts, ...ordered, ...partial];
        _orders.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('ไม่มีใบสั่งซื้อค้างรับ',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (ctx, i) {
        final order = _orders[i];
        final dt = DateTime.parse(order['createdAt'].toString());
        final status = order['status'];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: status == 'DRAFT'
                  ? Colors.grey[200]
                  : (status == 'PARTIAL' ? Colors.blue[100] : Colors.orange[100]),
              child: Icon(
                status == 'DRAFT' ? Icons.edit_note : (status == 'PARTIAL' ? Icons.access_time : Icons.local_shipping),
                color: status == 'DRAFT' ? Colors.grey : (status == 'PARTIAL' ? Colors.blue : Colors.orange),
              ),
            ),
            title: Text('PO #${order['id']} | Ref: ${order['documentNo'] ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('ผู้ขาย: ${order['supplierName'] ?? 'ไม่ระบุ'}'),
                Text('วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
                Text('สถานะ: $status',
                    style: TextStyle(
                      color: status == 'DRAFT' ? Colors.grey : (status == 'PARTIAL' ? Colors.blue : Colors.orange),
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0.00').format(double.tryParse(order['totalAmount'].toString()) ?? 0)} ฿',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Text('${order['itemCount']} รายการ'),
                  ],
                ),
                const SizedBox(width: 8),
                if (status == 'PARTIAL') ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'ปิดจบบิล (ตัดของที่ไม่ได้ทิ้ง)',
                    onPressed: () => _closePartialOrder(order),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'ลบใบสั่งซื้อ',
                  onPressed: () => _deleteOrder(order),
                ),
              ],
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('จัดการใบสั่งซื้อ #${order['id']}')),
                    body: StockInCreatePage(existingPoId: int.tryParse(order['id'].toString())),
                  ),
                ),
              );
              if (result == true || (result is String && result.isNotEmpty)) {
                _loadData();
                widget.onRefresh?.call();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _closePartialOrder(Map<String, dynamic> order) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ปิดจบบิลรับเข้าบางส่วน?',
      content: 'ระบบจะตัดรายการสินค้าที่ยังไม่ได้รับออกทั้งหมด และบันทึกใบสั่งซื้อนี้เป็นจัดส่งเสร็จสิ้น (RECEIVED)\nคุณต้องการดำเนินการต่อใช่หรือไม่?',
      confirmText: 'ปิดจบบิล',
      cancelText: 'ยกเลิก',
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _stockRepo.closePartialPurchaseOrder(int.tryParse(order['id'].toString()) ?? 0);
      if (mounted) {
        Navigator.pop(context);
        _loadData();
        widget.onRefresh?.call();
        AlertService.show(context: context, message: 'ปิดจบบิลเรียบร้อยรายการที่ค้างรับถูกยกเลิกแล้ว', type: 'success');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ลบใบสั่งซื้อ #${order['id']}?',
      content: 'คุณต้องการลบรายการนี้ใช่หรือไม่?\n(การกระทำนี้ไม่สามารถย้อนกลับได้)',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
    );
    if (confirm != true) return;
    try {
      await _stockRepo.deletePurchaseOrder(int.tryParse(order['id'].toString()) ?? 0);
      _loadData();
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'ไม่สามารถลบได้: $e', type: 'error');
      }
    }
  }
}
