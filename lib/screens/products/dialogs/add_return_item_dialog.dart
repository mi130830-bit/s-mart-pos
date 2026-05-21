import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/order_item.dart';
import '../../../models/product.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../controllers/stock_return_controller.dart';
import '../product_selection_dialog.dart';

class AddReturnItemDialog extends ConsumerStatefulWidget {
  const AddReturnItemDialog({super.key});

  @override
  ConsumerState<AddReturnItemDialog> createState() => _AddReturnItemDialogState();
}

class _AddReturnItemDialogState extends ConsumerState<AddReturnItemDialog> {
  final TextEditingController _dialogOrderIdCtrl = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _foundOrder;
  List<OrderItem>? _foundOrderItems;
  Map<int, double> _returnedMap = {};
  final Map<int, TextEditingController> _qtyControllers = {};

  @override
  void dispose() {
    _dialogOrderIdCtrl.dispose();
    for (var ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _searchOrder() async {
    final id = int.tryParse(_dialogOrderIdCtrl.text);
    if (id == null) return;

    setState(() => _isSearching = true);
    
    final controller = ref.read(stockReturnProvider.notifier);
    final res = await controller.searchOrder(id);
    
    setState(() => _isSearching = false);

    if (res != null) {
      setState(() {
        _foundOrder = res['order'];
        _foundOrderItems = res['items'] as List<OrderItem>;
        _returnedMap = res['returnedMap'] as Map<int, double>? ?? {};

        // Reset and populate controllers
        for (var ctrl in _qtyControllers.values) {
          ctrl.dispose();
        }
        _qtyControllers.clear();
        for (var item in _foundOrderItems!) {
          _qtyControllers[item.productId] = TextEditingController();
        }
      });
    } else {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'ไม่พบเลขที่บิลนี้',
          type: 'warning',
        );
      }
    }
  }

  Future<void> _searchByProduct() async {
    final controller = ref.read(stockReturnProvider.notifier);
    
    // 1. เลือกสินค้า
    final picked = await showDialog<Product>(
      context: context,
      builder: (c) => ProductSelectionDialog(repo: controller.productRepo),
    );

    if (picked != null) {
      if (!mounted) return;
      
      // 2. ดึงข้อมูลจาก Controller
      final orders = await controller.findOrdersByProduct(picked.id);

      if (!mounted) return;

      if (orders.isEmpty) {
        AlertService.show(
          context: context,
          message: 'ไม่พบประวัติการขายสินค้านี้',
          type: 'warning',
        );
        return;
      }

      // 3. แสดงหน้าต่างเลือกบิล
      final selectedOrder = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('ประวัติการขาย: ${picked.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (ctx, i) {
                final o = orders[i];
                final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(
                    DateTime.tryParse(o['createdAt'].toString()) ??
                        DateTime.now());
                return ListTile(
                  title: Text('บิล #${o['orderId']}'),
                  subtitle: Text(
                      '$dateStr | ลูกค้า: ${o['firstName'] ?? o['customerName'] ?? 'ทั่วไป'}'),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                  onTap: () => Navigator.pop(ctx, o),
                );
              },
            ),
          ),
        ),
      );

      // 4. ค้นหาบิลตามออเดอร์ที่เลือก
      if (selectedOrder != null) {
        _dialogOrderIdCtrl.text = selectedOrder['orderId'].toString();
        _searchOrder();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มรายการคืนสินค้า (Add Item)'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ส่วนค้นหา
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _dialogOrderIdCtrl,
                      label: 'เลขที่บิล (Order ID)',
                      hint: 'ระบุเลขบิล หรือกดค้นหาจากสินค้า',
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _searchOrder(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CustomButton(
                    onPressed: _isSearching ? null : _searchOrder,
                    icon: Icons.search,
                    label: 'ค้นหาบิล',
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'ค้นหาจากชื่อสินค้า',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _searchByProduct,
                        icon: const Icon(Icons.inventory, color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_isSearching) const LinearProgressIndicator(),

              // ส่วนเลือกรายการ
              if (_foundOrder != null && _foundOrderItems != null) ...[
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.grey),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'บิล #${_foundOrder!['id']} | วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(_foundOrder!['createdAt'].toString()) ?? DateTime.now())}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'ลูกค้า: ${_foundOrder!['firstName'] ?? "ทั่วไป"}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text('เลือกสินค้าที่ต้องการคืน',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // List of items in the order
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _foundOrderItems!.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = _foundOrderItems![i];
                        final returned = _returnedMap[item.productId] ?? 0.0;
                        final remaining = item.quantity.toDouble() - returned;
                        final isOutOfStock = remaining <= 0;

                        return ListTile(
                          dense: true,
                          title: Text(item.productName,
                              style: TextStyle(
                                  color: isOutOfStock
                                      ? Colors.grey
                                      : Colors.black,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'ซื้อ: ${item.quantity.toDouble().toStringAsFixed(0)} / คืนแล้ว: ${returned.toStringAsFixed(0)} / คงเหลือ: ${remaining.toStringAsFixed(0)}'),
                          trailing: SizedBox(
                            width: 80,
                            child: CustomTextField(
                              controller: _qtyControllers[item.productId],
                              readOnly: isOutOfStock,
                              hint: '0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        CustomButton(
          onPressed: () => Navigator.pop(context),
          label: 'ยกเลิก',
          type: ButtonType.secondary,
        ),
        CustomButton(
          onPressed: () {
            if (_foundOrder != null && _foundOrderItems != null) {
              bool addedAny = false;
              final controller = ref.read(stockReturnProvider.notifier);
              
              for (var item in _foundOrderItems!) {
                final ctrl = _qtyControllers[item.productId];
                if (ctrl == null) continue;

                final qty = double.tryParse(ctrl.text) ?? 0;
                if (qty <= 0) continue;

                final returned = _returnedMap[item.productId] ?? 0.0;
                final remaining = item.quantity.toDouble() - returned;

                if (qty > remaining) {
                  AlertService.show(
                      context: context,
                      message:
                          'จำนวนคืนของ ${item.productName} มากกว่าจำนวนคงเหลือ',
                      type: 'error');
                  return; // Stop and let user fix
                }

                controller.addReturnEntry(ReturnEntry(
                  orderId: int.parse(_foundOrder!['id'].toString()),
                  productId: item.productId,
                  productName: item.productName,
                  price: item.price.toDouble(),
                  returnQty: qty,
                  maxReturnable: item.quantity.toDouble(),
                  customerName: '${_foundOrder!['firstName'] ?? "-"}',
                ));
                addedAny = true;
              }

              if (addedAny) {
                Navigator.pop(context);
              }
            }
          },
          label: 'ตกลง (Add Selected)',
        ),
      ],
    );
  }
}
