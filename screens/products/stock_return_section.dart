import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/order_item.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../services/alert_service.dart';

// Import ไฟล์เพื่อนบ้าน
import 'stock_ledger_views.dart';
import 'product_selection_dialog.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

// Model สำหรับเก็บรายการในตะกร้าคืนของ
class ReturnEntry {
  final int orderId;
  final int productId;
  final String productName;
  final double price;
  double returnQty;
  final double maxReturnable; // จำนวนสูงสุดที่คืนได้ (ซื้อ - คืนไปแล้ว)
  final String customerName;

  ReturnEntry({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.returnQty,
    required this.maxReturnable,
    required this.customerName,
  });

  double get totalRefund => returnQty * price;
}

class StockReturnSection extends StatefulWidget {
  const StockReturnSection({super.key});

  @override
  State<StockReturnSection> createState() => _StockReturnSectionState();
}

class _StockReturnSectionState extends State<StockReturnSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabMgr;

  @override
  void initState() {
    super.initState();
    _tabMgr = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header & Tabs (สไตล์เดียวกับ Stock In)
        Container(
          color: Colors.orange.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabMgr,
                  isScrollable: true,
                  labelColor: Colors.deepOrange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepOrange,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.assignment_return),
                      text: 'ทำรายการคืน (Create Return)',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'ประวัติการรับคืน (History)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabMgr,
            children: [
              // Tab 1: Create Return Page
              const StockReturnCreatePage(),
              // Tab 2: History (Reuse Generic List)
              const GenericStockHistoryList(transactionType: 'RETURN_IN'),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// หน้าจอทำรายการคืนสินค้า (แยกออกมาเป็น Widget หลัก)
// ---------------------------------------------------------------------------
class StockReturnCreatePage extends StatefulWidget {
  const StockReturnCreatePage({super.key});

  @override
  State<StockReturnCreatePage> createState() => _StockReturnCreatePageState();
}

class _StockReturnCreatePageState extends State<StockReturnCreatePage> {
  final ProductRepository _productRepo = ProductRepository();
  final SalesRepository _salesRepo = SalesRepository();

  // รายการที่จะทำการคืน (Cart)
  final List<ReturnEntry> _returnItems = [];
  double get _totalRefundAmount =>
      _returnItems.fold(0.0, (sum, item) => sum + item.totalRefund);

  // --- 1. ฟังก์ชันเปิด Dialog เพิ่มรายการคืน ---
  Future<void> _openAddReturnItemDialog() async {
    // ตัวแปรภายใน Dialog state
    final TextEditingController dialogOrderIdCtrl = TextEditingController();
    bool isSearching = false;
    Map<String, dynamic>? foundOrder;
    List<OrderItem>? foundOrderItems;
    Map<int, double> returnedMap = {};
    final Map<int, TextEditingController> qtyControllers = {};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // ฟังก์ชันค้นหาบิลใน Dialog
          Future<void> searchOrder() async {
            final id = int.tryParse(dialogOrderIdCtrl.text);
            if (id == null) return;

            setDialogState(() => isSearching = true);
            final res = await _salesRepo.getOrderWithItems(id);
            setDialogState(() => isSearching = false);

            if (res != null) {
              setDialogState(() {
                foundOrder = res['order'];
                foundOrderItems = res['items'] as List<OrderItem>;
                returnedMap = res['returnedMap'] as Map<int, double>? ?? {};

                // Reset and populate controllers
                for (var ctrl in qtyControllers.values) {
                  ctrl.dispose();
                }
                qtyControllers.clear();
                for (var item in foundOrderItems!) {
                  qtyControllers[item.productId] = TextEditingController();
                }
              });
            } else {
              if (context.mounted) {
                AlertService.show(
                  context: context,
                  message: 'ไม่พบเลขที่บิลนี้',
                  type: 'warning',
                );
              }
            }
          }

          // ฟังก์ชันค้นหาจากสินค้า
          Future<void> searchByProduct() async {
            final products = await _productRepo.getAllProducts();
            if (!context.mounted) return;

            final picked = await showDialog<Product>(
              context: context,
              builder: (c) => ProductSelectionDialog(products: products),
            );

            if (picked != null) {
              setDialogState(() => isSearching = true);
              final orders = await _salesRepo.findOrdersByProduct(picked.id);
              setDialogState(() => isSearching = false);

              if (!context.mounted) return;

              if (orders.isEmpty) {
                AlertService.show(
                  context: context,
                  message: 'ไม่พบประวัติการขายสินค้านี้',
                  type: 'warning',
                );
                return;
              }

              // ให้เลือกบิล
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

              if (selectedOrder != null) {
                dialogOrderIdCtrl.text = selectedOrder['orderId'].toString();
                await searchOrder(); // ค้นหาต่อเลย
              }
            }
          }

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
                            controller: dialogOrderIdCtrl,
                            label: 'เลขที่บิล (Order ID)',
                            hint: 'ระบุเลขบิล หรือกดค้นหาจากสินค้า',
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => searchOrder(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CustomButton(
                          onPressed: isSearching ? null : searchOrder,
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
                              onPressed: searchByProduct,
                              icon: const Icon(Icons.inventory,
                                  color: Colors.blue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (isSearching) const LinearProgressIndicator(),

                    // ส่วนเลือกรายการ
                    if (foundOrder != null && foundOrderItems != null) ...[
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
                                    'บิล #${foundOrder!['id']} | วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(foundOrder!['createdAt'].toString()) ?? DateTime.now())}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'ลูกค้า: ${foundOrder!['firstName'] ?? "ทั่วไป"}'),
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
                            itemCount: foundOrderItems!.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = foundOrderItems![i];
                              final returned =
                                  returnedMap[item.productId] ?? 0.0;
                              final remaining =
                                  item.quantity.toDouble() - returned;
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
                                    controller: qtyControllers[item.productId],
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
                  if (foundOrder != null && foundOrderItems != null) {
                    bool addedAny = false;
                    for (var item in foundOrderItems!) {
                      final ctrl = qtyControllers[item.productId];
                      if (ctrl == null) continue;

                      final qty = double.tryParse(ctrl.text) ?? 0;
                      if (qty <= 0) continue;

                      final returned = returnedMap[item.productId] ?? 0.0;
                      final remaining = item.quantity.toDouble() - returned;

                      if (qty > remaining) {
                        AlertService.show(
                            context: context,
                            message:
                                'จำนวนคืนของ ${item.productName} มากกว่าจำนวนคงเหลือ',
                            type: 'error');
                        return; // Stop and let user fix
                      }

                      // Check if already in main list (optional: merge or skip)
                      // For simplicity, just add
                      _returnItems.add(ReturnEntry(
                        orderId: int.parse(foundOrder!['id'].toString()),
                        productId: item.productId,
                        productName: item.productName,
                        price: item.price.toDouble(),
                        returnQty: qty,
                        maxReturnable: item.quantity.toDouble(),
                        customerName: '${foundOrder!['firstName'] ?? "-"}',
                      ));
                      addedAny = true;
                    }

                    if (addedAny) {
                      setState(() {});
                      Navigator.pop(context);
                    }
                  }
                },
                label: 'ตกลง (Add Selected)',
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 2. ฟังก์ชันบันทึกทั้งหมด (Batch Save) ---
  Future<void> _saveReturnBatch() async {
    if (_returnItems.isEmpty) return;

    bool confirm = await ConfirmDialog.show(
          context,
          title: 'ยืนยันการคืนสินค้า',
          content:
              'ต้องการคืนสินค้าจำนวน ${_returnItems.length} รายการ\nรวมเป็นเงิน ${NumberFormat('#,##0.00').format(_totalRefundAmount)} บาท หรือไม่?',
          confirmText: 'ยืนยัน',
          cancelText: 'ยกเลิก',
        ) ??
        false;

    if (!confirm) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    int successCount = 0;
    for (var item in _returnItems) {
      bool res = await _salesRepo.processReturn(
        orderId: item.orderId,
        productId: item.productId,
        productName: item.productName,
        returnQty: item.returnQty,
        price: item.price,
      );
      if (res) successCount++;
    }

    if (!mounted) return;
    Navigator.pop(context); // ปิด Loading

    AlertService.show(
      context: context,
      message: 'บันทึกคืนสำเร็จ $successCount รายการ',
      type: 'success',
    );

    setState(() {
      _returnItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Toolbar & Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'รายการสินค้าที่รับคืน (New Return List)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              CustomButton(
                onPressed: _openAddReturnItemDialog,
                icon: Icons.add_shopping_cart,
                label: 'เพิ่มรายการคืน (F1)',
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),

        // 2. Table Header
        Container(
          decoration: const BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: const Row(
            children: [
              SizedBox(
                  width: 40,
                  child: Text('#',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('อ้างอิงบิล (Ref)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 3,
                  child: Text('สินค้า (Product)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 1,
                  child: Text('จำนวน',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('ราคา/หน่วย',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('รวมเงินคืน',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              SizedBox(
                  width: 50,
                  child: Center(
                      child: Text('ลบ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)))),
            ],
          ),
        ),

        // 3. Table Content
        Expanded(
          child: _returnItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_shopping_cart_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('ไม่มีรายการคืน',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _returnItems.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = _returnItems[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? Colors.white
                            : Colors.orange.withValues(alpha: 0.05),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text('${index + 1}')),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('#${item.orderId}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange)),
                                Text(item.customerName,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(item.productName,
                                style: const TextStyle(fontSize: 14)),
                          ),
                          Expanded(
                            flex: 1,
                            child: CustomTextField(
                              initialValue: item.returnQty.toString(),
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                final v = double.tryParse(val) ?? 0;
                                if (v > 0) {
                                  setState(() => item.returnQty = v);
                                }
                              },
                            ),
                          ),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  NumberFormat('#,##0.00').format(item.price),
                                  textAlign: TextAlign.right)),
                          Expanded(
                              flex: 2,
                              child: Text(
                                NumberFormat('#,##0.00')
                                    .format(item.totalRefund),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              )),
                          SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _returnItems.removeAt(index)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // 4. Footer Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ยอดเงินคืนรวม (Total Refund):',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      '฿${NumberFormat('#,##0.00').format(_totalRefundAmount)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomButton(
                  onPressed: _returnItems.isEmpty ? null : _saveReturnBatch,
                  icon: Icons.save,
                  label: 'บันทึกการคืน (Save Return)',
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
