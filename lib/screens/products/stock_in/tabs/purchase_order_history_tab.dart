import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/alert_service.dart';
import '../../../../models/supplier.dart';
import '../../../../widgets/common/custom_buttons.dart';
import '../../widgets/supplier_search_dialog.dart';
import '../dialogs/edit_received_qty_dialog.dart';
import '../pages/stock_in_create_page.dart';
import '../../controllers/purchase_order_history_controller.dart';

class PurchaseOrderHistoryTab extends ConsumerStatefulWidget {
  const PurchaseOrderHistoryTab({super.key});

  @override
  ConsumerState<PurchaseOrderHistoryTab> createState() =>
      _PurchaseOrderHistoryTabState();
}

class _PurchaseOrderHistoryTabState
    extends ConsumerState<PurchaseOrderHistoryTab> {
  Future<void> _pickSupplier(
      BuildContext context, PurchaseOrderHistoryController controller) async {
    final Supplier? selected = await showDialog<Supplier>(
      context: context,
      builder: (context) => const SupplierSearchDialog(),
    );
    if (selected != null) {
      controller.setSupplier(selected);
    }
  }

  Future<void> _pickDate(
      BuildContext context, PurchaseOrderHistoryState state, PurchaseOrderHistoryController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null && picked != state.selectedDate) {
      controller.setDate(picked);
    }
  }

  Future<void> _editReceivedOrder(BuildContext context,
      PurchaseOrderHistoryController controller, Map<String, dynamic> order) async {
    final poId = int.tryParse(order['id'].toString()) ?? 0;
    if (poId == 0) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
        
    final items = await controller.getOrderItems(poId);
    
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading
    
    if (items.isEmpty) return; // Error handled in controller

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

    if (!context.mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
        
    final success = await controller.updateReceivedOrder(order, result);
    
    if (!context.mounted) return;
    Navigator.pop(context); // close loading
    
    if (success) {
      AlertService.show(
          context: context,
          message: 'แก้ไขรายการรับเข้าเรียบร้อยแล้ว',
          type: 'success');
    }
  }

  Future<void> _deleteOrder(BuildContext context,
      PurchaseOrderHistoryController controller, Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'ต้องการลบใบรับเข้า #${order['documentNo'] ?? order['id']} และคืนสต็อกใช่หรือไม่?'),
        actions: [
          CustomButton(
              label: 'ยกเลิก',
              type: ButtonType.secondary,
              onPressed: () => Navigator.pop(ctx, false)),
          CustomButton(
              label: 'ยืนยันลบ',
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    
    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
          
      final poId = int.tryParse(order['id'].toString()) ?? 0;
      final success = await controller.deleteOrder(poId);
      
      if (!context.mounted) return;
      Navigator.pop(context); // close loading
      
      if (success) {
        AlertService.show(
            context: context,
            message: 'ลบรายการสั่งซื้อเรียบร้อยแล้ว',
            type: 'success');
      }
    }
  }

  Future<void> _togglePaymentStatus(BuildContext context,
      PurchaseOrderHistoryController controller, Map<String, dynamic> order) async {
    final newStatus = await controller.togglePaymentStatus(order);
    
    if (context.mounted && ref.read(purchaseOrderHistoryProvider).errorMessage == null) {
      AlertService.show(
        context: context,
        message: newStatus
            ? '✅ ทำเครื่องหมาย "จ่ายแล้ว" เรียบร้อย'
            : '⚠️ ทำเครื่องหมาย "ค้างจ่าย" เรียบร้อย',
        type: newStatus ? 'success' : 'warning',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseOrderHistoryProvider);
    final controller = ref.read(purchaseOrderHistoryProvider.notifier);
    
    ref.listen<PurchaseOrderHistoryState>(purchaseOrderHistoryProvider, (prev, next) {
      if (next.errorMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AlertService.show(
                context: context,
                message: next.errorMessage!,
                type: 'error');
            controller.clearError();
          }
        });
      }
    });

    if (state.isLoading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final displayOrders = state.orders;

    return Column(
      children: [
        // 🔎 Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(context, state, controller),
                icon: const Icon(Icons.calendar_today),
                label: Text(state.selectedDate == null
                    ? 'ทุกวัน (All Time)'
                    : 'วันที่: ${DateFormat('dd/MM/yyyy').format(state.selectedDate!)}'),
              ),
              if (state.selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'ล้างวันที่',
                  onPressed: () => controller.setDate(null),
                ),
              ],
              const SizedBox(width: 16),
              const VerticalDivider(),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickSupplier(context, controller),
                  icon: const Icon(Icons.store),
                  label: Text(
                    state.selectedSupplierId == null
                        ? 'ผู้ขาย: ทั้งหมด (All Suppliers)'
                        : 'ผู้ขาย: ${state.selectedSupplierName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              if (state.selectedSupplierId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'ล้างผู้ขาย',
                  onPressed: () => controller.clearSupplier(),
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
                    value: state.paymentFilter,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'ALL', child: Text('สถานะการเงิน: ทั้งหมด')),
                      DropdownMenuItem(
                          value: 'UNPAID',
                          child: Text('⚠️ ค้างจ่าย',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold))),
                      DropdownMenuItem(
                          value: 'PAID',
                          child: Text('✅ จ่ายแล้ว',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        controller.setPaymentFilter(val);
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
                const Text('ไม่พบประวัติการรับเข้าตามเงื่อนไข',
                    style: TextStyle(color: Colors.grey)),
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
                SizedBox(
                    width: 50,
                    child: Text('#',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('วันที่',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('เลขที่เอกสาร',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 3,
                    child: Text('ผู้ขาย',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 1,
                    child: Text('รายการ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 1,
                    child: Text('จ่ายเงิน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('ยอดรวม',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
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
                  final prevDt = DateTime.parse(
                      displayOrders[i - 1]['createdAt'].toString());
                  if (dt.month != prevDt.month || dt.year != prevDt.year) {
                    isNewMonth = true;
                  }
                }

                final itemWidget = InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                              title: Text(
                                  'รายละเอียดใบรับเข้า #${order['documentNo'] ?? order['id']}')),
                          body: StockInCreatePage(
                              existingPoId:
                                  int.tryParse(order['id'].toString())),
                        ),
                      ),
                    ).then((_) => controller.loadData());
                  },
                  child: Container(
                    color: i % 2 == 0
                        ? Colors.white
                        : Colors.indigo.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 50,
                            child: Text('${i + 1}',
                                style: const TextStyle(color: Colors.grey))),
                        Expanded(
                          flex: 2,
                          child: Builder(builder: (context) {
                            final updatedAtRaw = order['updatedAt'];
                            final createdAtRaw = order['createdAt'];
                            bool isModified = false;
                            String modifiedDateStr = '';
                            if (updatedAtRaw != null && createdAtRaw != null) {
                              try {
                                final updatedAt = DateTime.parse(
                                    updatedAtRaw.toString());
                                final createdAt = DateTime.parse(
                                    createdAtRaw.toString());
                                isModified = updatedAt
                                        .difference(createdAt)
                                        .inSeconds
                                        .abs() >=
                                    2;
                                if (isModified) {
                                  modifiedDateStr = DateFormat('dd/MM/yy HH:mm')
                                      .format(updatedAt);
                                }
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.15),
                                        border: Border.all(
                                            color: Colors.orange.shade400,
                                            width: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit,
                                              size: 10,
                                              color: Colors.orange.shade700),
                                          const SizedBox(width: 3),
                                          Text('ถูกแก้ไข',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ),
                        Expanded(
                            flex: 2,
                            child: Text(order['documentNo'] ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 3,
                            child: Text(order['supplierName'] ?? 'ไม่ระบุ')),
                        Expanded(
                            flex: 1,
                            child: Text('${order['itemCount']}',
                                textAlign: TextAlign.center)),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: InkWell(
                              onTap: () =>
                                  _togglePaymentStatus(context, controller, order),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (int.tryParse(
                                                  order['isPaid'].toString()) ??
                                              0) ==
                                          1
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (int.tryParse(order['isPaid']
                                                    .toString()) ??
                                                0) ==
                                            1
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                child: Text(
                                  (int.tryParse(order['isPaid'].toString()) ??
                                              0) ==
                                          1
                                      ? 'จ่ายแล้ว'
                                      : 'ค้างจ่าย',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (int.tryParse(
                                                    order['isPaid'].toString()) ??
                                                0) ==
                                            1
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            NumberFormat('#,##0.00').format(double.tryParse(
                                    order['totalAmount'].toString()) ??
                                0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.indigo, size: 20),
                            onPressed: () =>
                                _editReceivedOrder(context, controller, order),
                            tooltip: 'แก้ไขจำนวน',
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _deleteOrder(context, controller, order),
                            tooltip: 'ลบและคืนสต็อก',
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (isNewMonth) {
                  final monthYearLabel =
                      '${DateFormat('MMMM', 'th').format(dt)} ${dt.year + 543}';
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (i > 0) const Divider(height: 1, thickness: 2),
                      Container(
                        color: Colors.indigo.shade50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Text(monthYearLabel,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.indigo.shade800)),
                      ),
                      itemWidget,
                    ],
                  );
                }
                return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [const Divider(height: 1), itemWidget]);
              },
            ),
          ),
          // Summary Footer
          if (state.orders.isNotEmpty) ...[
            Builder(builder: (context) {
              final totalAll = state.orders.fold<double>(
                  0,
                  (s, o) =>
                      s +
                      (double.tryParse(o['totalAmount']?.toString() ?? '0') ??
                          0));
              final totalUnpaid = state.orders
                  .where((o) =>
                      (int.tryParse(o['isPaid']?.toString() ?? '0') ?? 0) == 0)
                  .fold<double>(
                      0,
                      (s, o) =>
                          s +
                          (double.tryParse(
                                  o['totalAmount']?.toString() ?? '0') ??
                              0));
              final totalPaid = totalAll - totalUnpaid;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    border: Border(
                        top: BorderSide(
                            color: Colors.indigo.shade100, width: 2))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300)),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        const Text('ค้างจ่าย: ',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '฿${NumberFormat('#,##0.00').format(totalUnpaid)}',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300)),
                      child: Row(children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        const Text('จ่ายแล้ว: ',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        Text('฿${NumberFormat('#,##0.00').format(totalPaid)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ]),
                    ),
                    const Spacer(),
                    const Text('รวมยอดสุทธิ: ',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo)),
                    Text('฿${NumberFormat('#,##0.00').format(totalAll)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
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
                  onPressed: state.currentPage > 1
                      ? () => controller.prevPage()
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('หน้าก่อนหน้า'),
                ),
                const SizedBox(width: 16),
                Text('หน้า ${state.currentPage}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: state.hasNextPage
                      ? () => controller.nextPage()
                      : null,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('หน้าถัดไป'),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right)
                  ]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
