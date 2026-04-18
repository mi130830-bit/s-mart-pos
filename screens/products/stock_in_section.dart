import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import '../../services/alert_service.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../models/unit.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/unit_repository.dart';

import 'product_multi_selection_dialog.dart';
import 'widgets/supplier_search_dialog.dart';
import 'product_list_view.dart'; // For ProductFormDialog
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

class StockInItem {
  Product product; // ✅ Mutable for delayed ID update
  double quantity;
  double receivedQuantity; // ✅ New field
  double costPrice;
  int vatType;

  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;

  StockInItem({
    required this.product,
    required this.quantity,
    required this.costPrice,
    this.vatType = 0,
    this.receivedQuantity = 0.0,
  })  : qtyCtrl = TextEditingController(
            text: quantity > 0
                ? quantity
                    .toString()
                    .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "")
                : ""),
        costCtrl = TextEditingController(
            text: costPrice
                .toStringAsFixed(4)
                .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), ""));

  double get total => quantity * costPrice;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

class StockInSection extends StatefulWidget {
  const StockInSection({super.key});

  @override
  State<StockInSection> createState() => _StockInSectionState();
}

class _StockInSectionState extends State<StockInSection>
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
        // Header & Tabs
        Container(
          color: Colors.indigo.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabMgr,
                  isScrollable: true,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.assignment_outlined),
                      text: 'ใบสั่งซื้อ (Purchase Orders)',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'ประวัติรับเข้า (Received)',
                    ),
                  ],
                ),
              ),
              CustomButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('สร้างรายการใหม่')),
                        body: const StockInCreatePage(),
                      ),
                    ),
                  ).then((val) {
                    if (val != null) {
                      setState(() {});
                      // If 'RECEIVED', switch to tab 1
                      if (val == 'RECEIVED') {
                        _tabMgr.animateTo(1);
                      }
                    }
                  });
                },
                icon: Icons.add,
                label: 'สร้างใบสั่ง/รับของ',
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
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
              // Tab 1: Purchase Order List (Pending/Ordered)
              PurchaseOrderList(onRefresh: () => setState(() {})),
              // Tab 2: Purchase Order History (Received)
              const PurchaseOrderHistoryTable(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase Order List Widget
// ---------------------------------------------------------------------------
class PurchaseOrderList extends StatefulWidget {
  final VoidCallback? onRefresh;
  const PurchaseOrderList({super.key, this.onRefresh});

  @override
  State<PurchaseOrderList> createState() => _PurchaseOrderListState();
}

class _PurchaseOrderListState extends State<PurchaseOrderList> {
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
      // Load DRAFT, ORDERED, and PARTIAL
      final drafts = await _stockRepo.getPurchaseOrders(status: 'DRAFT');
      final ordered = await _stockRepo.getPurchaseOrders(status: 'ORDERED');
      final partial = await _stockRepo.getPurchaseOrders(status: 'PARTIAL');
      setState(() {
        _orders = [...drafts, ...ordered, ...partial];
        // Sort by CreatedAt desc
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: status == 'DRAFT'
                  ? Colors.grey[200]
                  : (status == 'PARTIAL'
                      ? Colors.blue[100]
                      : Colors.orange[100]),
              child: Icon(
                status == 'DRAFT'
                    ? Icons.edit_note
                    : (status == 'PARTIAL'
                        ? Icons.access_time
                        : Icons.local_shipping),
                color: status == 'DRAFT'
                    ? Colors.grey
                    : (status == 'PARTIAL' ? Colors.blue : Colors.orange),
              ),
            ),
            title: Text(
              'PO #${order['id']} | Ref: ${order['documentNo'] ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('ผู้ขาย: ${order['supplierName'] ?? 'ไม่ระบุ'}'),
                Text('วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
                Text(
                  'สถานะ: $status',
                  style: TextStyle(
                    color: status == 'DRAFT'
                        ? Colors.grey
                        : (status == 'PARTIAL' ? Colors.blue : Colors.orange),
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
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
              // Open to Receive or Edit
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar:
                        AppBar(title: Text('จัดการใบสั่งซื้อ #${order['id']}')),
                    body: StockInCreatePage(
                        existingPoId: int.tryParse(order['id'].toString())),
                  ),
                ),
              );
              if (result == true || (result is String && result.isNotEmpty)) {
                _loadData(); // Refresh list
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _stockRepo.closePartialPurchaseOrder(int.tryParse(order['id'].toString()) ?? 0);
      if (mounted) {
        Navigator.pop(context); // close loading
        _loadData(); // Refresh list
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
      content:
          'คุณต้องการลบรายการนี้ใช่หรือไม่?\n(การกระทำนี้ไม่สามารถย้อนกลับได้)',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
    );

    if (confirm != true) return;

    try {
      await _stockRepo
          .deletePurchaseOrder(int.tryParse(order['id'].toString()) ?? 0);
      _loadData(); // Refresh
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'ไม่สามารถลบได้: $e',
          type: 'error',
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Create / Edit / Receive Page
// ---------------------------------------------------------------------------
class StockInCreatePage extends StatefulWidget {
  final int? existingPoId;
  const StockInCreatePage({super.key, this.existingPoId});

  @override
  State<StockInCreatePage> createState() => _StockInCreatePageState();
}

class _StockInCreatePageState extends State<StockInCreatePage> {
  final ProductRepository _productRepo = ProductRepository();
  final SupplierRepository _supplierRepo = SupplierRepository();
  final StockRepository _stockRepo = StockRepository();
  final UnitRepository _unitRepo = UnitRepository();

  final List<StockInItem> _stockInItems = [];
  final TextEditingController _docNoCtrl = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Unit> _units = [];
  int? _selectedSupplierId;
  String _poStatus = 'NEW'; // NEW, DRAFT, ORDERED, RECEIVED
  int _vatType = 0; // 0=Included, 1=Excluded, 2=NoVAT

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _docNoCtrl.dispose();
    for (var item in _stockInItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final s = await _supplierRepo.getAllSuppliers();
    final u = await _unitRepo.getAllUnits();

    if (widget.existingPoId != null) {
      await _loadPoData(widget.existingPoId!);
    }
    // else {
    //   if (s.isNotEmpty) {
    //     _selectedSupplierId = s.first.id;
    //   }
    // }

    if (!mounted) return;
    setState(() {
      _suppliers = s;
      _units = u;
    });
  }

  Future<void> _loadPoData(int poId) async {
    try {
      final items = await _stockRepo.getPurchaseOrderItems(poId);
      final header = await _stockRepo.getPurchaseOrderById(poId);

      if (header == null) return;

      if (header.isNotEmpty) {
        _selectedSupplierId = int.tryParse(header['supplierId'].toString());
        _docNoCtrl.text = header['documentNo'] ?? '';
        _poStatus = header['status'] ?? 'NEW';
        _vatType = int.tryParse(header['vatType'].toString()) ?? 0;

        // ✅ Batch Load Products (Optimized)
        final List<int> productIds = items
            .map((e) => int.tryParse(e['productId'].toString()) ?? 0)
            .where((id) => id > 0)
            .toList();

        final Map<int, Product> productMap = {};
        if (productIds.isNotEmpty) {
          final products = await _productRepo.getProductsByIds(productIds);
          for (var p in products) {
            productMap[p.id] = p;
          }
        }

        // Load products for items
        for (var item in items) {
          final prodId = int.tryParse(item['productId'].toString()) ?? 0;
          final p = productMap[prodId];

          final double qty = double.tryParse(item['quantity'].toString()) ?? 0;
          final double received =
              double.tryParse(item['receivedQuantity'].toString()) ?? 0;

          if (p != null) {
            _stockInItems.add(StockInItem(
              product: p,
              quantity: qty,
              costPrice: double.tryParse(item['costPrice'].toString()) ?? 0,
              vatType: p.vatType,
              receivedQuantity: received, // ✅ Added
            ));
          } else {
            // ✅ Fallback for Deleted Product
            final dummyProduct = Product(
              id: prodId,
              name: 'สินค้าที่ถูกลบ (ID: ${item['productId']})',
              barcode: '',
              productType: 0,
              costPrice: 0,
              retailPrice: 0,
              stockQuantity: 0,
              points: 0,
              trackStock: false,
            );
            _stockInItems.add(StockInItem(
              product: dummyProduct,
              quantity: qty,
              costPrice: double.tryParse(item['costPrice'].toString()) ?? 0,
              vatType: 0,
              receivedQuantity: received, // ✅ Added
            ));
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Error loading PO Data: $e\n$stack');
    }
  }

  Future<void> _addProductToStockIn() async {
    if (!mounted) return;

    // Use Multi Selection Dialog
    final List<Product>? pickedList = await showDialog<List<Product>>(
      context: context,
      builder: (context) => ProductMultiSelectionDialog(
        initialSelectedIds: [], // No pre-selection for new add
        repo: _productRepo,
      ),
    );

    if (pickedList != null && pickedList.isNotEmpty) {
      setState(() {
        for (var picked in pickedList) {
          final existingIndex = _stockInItems.indexWhere(
            (i) => i.product.id == picked.id,
          );
          if (existingIndex >= 0) {
            _stockInItems[existingIndex].quantity += 1;
          } else {
            _stockInItems.add(
              StockInItem(
                product: picked,
                quantity: 1,
                costPrice: picked.costPrice,
                vatType: picked.vatType,
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _createNewProduct() async {
    final Product? newProduct = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductFormDialog(
        repo: _productRepo,
        delayedSave: true, // ✅ Don't save to DB yet
      ),
    );

    if (newProduct != null && mounted) {
      setState(() {
        _stockInItems.add(
          StockInItem(
            product: newProduct,
            quantity: 1,
            costPrice: newProduct.costPrice,
            vatType: newProduct.vatType,
          ),
        );
      });
    }
  }

  // ✅ New Method: Edit Product Details from Stock In Screen
  Future<void> _editProductDetail(StockInItem item) async {
    final Product? updatedProduct = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ProductFormDialog(repo: _productRepo, product: item.product),
    );

    if (updatedProduct != null && mounted) {
      setState(() {
        // Find all items with this product ID and update them
        // (In case added multiple times, though usually unique here)
        for (var i = 0; i < _stockInItems.length; i++) {
          if (_stockInItems[i].product.id == updatedProduct.id) {
            // Re-create item with new product data but keep qty/cost
            // Actually simplest is to just update the 'product' field if it was mutable,
            // but it is final. So replace the StockInItem.
            final oldItem = _stockInItems[i];
            _stockInItems[i] = StockInItem(
              product: updatedProduct,
              quantity: oldItem.quantity,
              costPrice: oldItem
                  .costPrice, // Keep trip cost or update? Usually keep trip cost.
              vatType: updatedProduct.vatType,
            );
          }
        }
      });
      // Tip: Cost Price in Master Data might have changed too,
      // but here we usually preserve the "Transaction Cost" entered by user.
      // If user WANTS to update cost to match new master, they can re-type.
    }
  }

  Future<void> _showCostCalculator(StockInItem item) async {
    double tempTotal = item.total;
    final totalCtrl = TextEditingController(text: tempTotal.toString());
    final discountCtrl = TextEditingController(text: "0");

    double calculateCostPerUnit() {
      double t = double.tryParse(totalCtrl.text) ?? 0.0;
      double d = double.tryParse(discountCtrl.text) ?? 0.0;
      double qty = item.quantity;
      if (qty == 0) return 0.0;
      return (t - d) / qty;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentCostPerUnit = calculateCostPerUnit();
            return AlertDialog(
              title: const Text('คำนวณต้นทุนสินค้า'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สินค้า: ${item.product.name}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: totalCtrl,
                    label: 'ต้นทุนรวม (Total Cost)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: discountCtrl,
                    label: 'ส่วนลดรวม (Total Discount)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'ต้นทุนต่อหน่วย: ${NumberFormat('#,##0.0000').format(currentCostPerUnit)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                CustomButton(
                  onPressed: () => Navigator.pop(context),
                  label: 'ยกเลิก',
                  type: ButtonType.secondary,
                ),
                CustomButton(
                  onPressed: () {
                    setState(() {
                      item.costPrice = calculateCostPerUnit();
                      item.costCtrl.text = item.costPrice
                          .toStringAsFixed(4)
                          .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
                    });
                    Navigator.pop(context);
                  },
                  label: 'ยืนยัน',
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _processAction(String targetStatus) async {
    if (_stockInItems.isEmpty) return;

    // ✅ Validation: Check Supplier
    if (_selectedSupplierId == null || _selectedSupplierId == 0) {
      AlertService.show(
        context: context,
        message: 'กรุณาเลือกผู้ขายก่อน',
        type: 'warning',
      );
      return;
    }

    // ✅ 0. Auto-Save Pending Products (Delayed Save)
    // Find items with ID = 0 and save them now
    final pendingItems = _stockInItems.where((i) => i.product.id == 0).toList();
    if (pendingItems.isNotEmpty) {
      // Show loading indicator distinct from main one? Or just share same loading?
      // Since we show loading below, let's just do it here implicitly or move loading up.
      // Better to move loading up to cover this phase.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        for (var item in pendingItems) {
          // ✅ Allow empty barcode (Database should allow NULL)
          // Removed auto-generation logic to satisfy user requirement:
          // "Leave barcode empty first... go create automatically when receiving"
          // if (item.product.barcode == null || ...) { ... }

          int newId = await _productRepo.saveProduct(item.product);
          if (newId > 0) {
            // Update item with new ID
            setState(() {
              item.product = item.product.copyWith(id: newId);
            });
            // If we also need to save tiers/barcodes, we should ideally handle that.
            // But ProductFormDialog returns a Product object. Tiers/Components are separate.
            // If those were "in-memory", we might lose them here unless Product model holds them.
            // Product model HAS components and tiers lists but usually null.
            // Currently ProductFormDialog saves tiers/components separately inside _save.
            // If delayedSave is true, ProductFormDialog skips all saving.
            // AND it returns `newProduct` which MIGHT NOT contain tiers/components populated in `priceTiers` field?
            // Let's check ProductFormDialog logic roughly.
            // It creates `newProduct` but doesn't attach `_priceTiers` to it explicitly for return?
            // Line 871: `final newProduct = Product(...)`. `components` is passed from input?
            // No, `components` field in Product is generic dynamic list.
            // WE MIGHT LOSE TIERS/COMPONENTS logic here.
            // But for "Simple Product Creation" in PO, user likely just adds Name/Price.
            // We assume simple product for now.
          }
        }
        if (mounted) Navigator.pop(context); // Close loading
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          AlertService.show(
            context: context,
            message: 'Error saving new products: $e',
            type: 'error',
          );
        }
        return;
      }
    }

    // ✅ 2. Partial Receive Logic Switch
    if (widget.existingPoId != null &&
        (_poStatus == 'ORDERED' ||
            _poStatus == 'PARTIAL' ||
            _poStatus == 'DRAFT') &&
        targetStatus == 'RECEIVED') {
      if (!mounted) return;
      // Ask User: Full or Partial
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการรับสินค้า'),
          content: const Text('เลือกรูปแบบการรับสินค้า:\n\n'
              '• รับทั้งหมด: รับสินค้าครบทุกรายการตามใบสั่งซื้อ\n'
              '• รับบางส่วน: เลือกรับเฉพาะรายการที่มาถึง (รายการที่เหลือจะค้างอยู่ใน PO เดิม)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'CANCEL'),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'PARTIAL'),
              child: const Text('รับบางส่วน'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'FULL'),
              child: const Text('รับทั้งหมด'),
            ),
          ],
        ),
      );

      if (choice == 'CANCEL' || choice == null) return;
      if (choice == 'PARTIAL') {
        await _handlePartialReceive();
        return;
      }
      // If FULL, continue to normal flow below...
    }

    if (!mounted) return;

    // Confirmation (Normal Flow)
    final bool isEditingReceived =
        widget.existingPoId != null && _poStatus == 'RECEIVED';

    final bool? confirm = await ConfirmDialog.show(
      context,
      title: targetStatus == 'RECEIVED'
          ? (isEditingReceived
              ? 'ยืนยันการแก้ไขข้อมูลรับเข้า?'
              : 'ยืนยันการรับเข้าสินค้า?')
          : 'บันทึกใบสั่งซื้อ?',
      content: targetStatus == 'RECEIVED'
          ? (isEditingReceived
              ? 'ระบบจะทำการหักลบยอดเดิมออกทั้งหมด และบันทึกยอดใหม่เข้าไปแทน\n(สต็อกจะถูกปรับให้ตรงกับยอดใหม่)'
              : 'สินค้าจะถูกเพิ่มเข้าสต็อกทันทีและราคาทุนจะถูกอัปเดต')
          : 'บันทึกเป็นใบสั่งซื้อ (ยังไม่เข้าสต็อก)',
      confirmText: 'ยืนยัน',
      cancelText: 'ยกเลิก',
    );

    if (confirm != true) return;
    if (!mounted) return;

    // Process
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final itemsMap = _stockInItems
          .map((item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'quantity': item.quantity,
                'costPrice': item.costPrice,
                'total': item.total,
              })
          .toList();

      if (widget.existingPoId != null) {
        await _stockRepo.updatePurchaseOrder(
          poId: widget.existingPoId!,
          totalAmount: _totalCost,
          items: itemsMap,
          documentNo: _docNoCtrl.text,
          status: targetStatus,
          vatType: _vatType,
        );
      } else {
        await _stockRepo.createPurchaseOrder(
          supplierId: _selectedSupplierId!,
          totalAmount: _totalCost,
          items: itemsMap,
          documentNo: _docNoCtrl.text,
          status: targetStatus,
          vatType: _vatType,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Close dialog
        AlertService.show(
          context: context,
          message:
              'บันทึก ${targetStatus == 'ORDERED' ? 'ใบสั่งซื้อ' : 'รับสินค้า'} เรียบร้อยแล้ว',
          type: 'success',
        );
        Navigator.pop(context, targetStatus); // Return status string
      }
    } catch (e) {
      if (mounted) {
        // Fix: Use Future.delayed to avoid 'debugLocked' error if error happens too fast
        await Future.delayed(Duration.zero);
        if (!mounted) return;
        Navigator.pop(context); // Remove loading
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    }
  }

  // ✅ UI สำหรับเลือกรับบางรายการ (Partial Receive)
  Future<void> _handlePartialReceive() async {
    // 1. Show Selection Dialog
    final List<Map<String, dynamic>>? selectedItems =
        await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false, // Prevent accidental close
      builder: (context) => _PartialReceiveDialog(items: _stockInItems),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    // 2. Validate
    if (!mounted) return;

    // Give UI time to close the previous dialog completely
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Process
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _stockRepo.receivePartialPurchaseOrder(
        originalPoId: widget.existingPoId!,
        receivedItems: selectedItems,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close Loading

        AlertService.show(
          context: context,
          message: '✅ บันทึกยอดรับสินค้าเรียบร้อยแล้ว (Updated Received Qty)',
          type: 'success',
        );

        // Wait slightly before closing page to let SnackBar appear logic settle (optional but safe)
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          Navigator.of(context)
              .pop('RECEIVED'); // Return 'RECEIVED' to force tab switch
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close Loading
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  double get _totalCost {
    double sum = _stockInItems.fold(0.0, (sum, item) => sum + item.total);
    if (_vatType == 1) {
      // Excluded: Add 7%
      return sum * 1.07;
    }
    return sum;
  }

  String _getThaiStatus(String status) {
    switch (status) {
      case 'NEW':
        return 'สร้างใหม่';
      case 'DRAFT':
        return 'ร่าง';
      case 'ORDERED':
        return 'สั่งซื้อแล้ว';
      case 'RECEIVED':
        return 'รับแล้ว';
      case 'PARTIAL':
        return 'รับบางส่วน';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.existingPoId != null
                      ? 'จัดการใบสั่งซื้อ #${widget.existingPoId} (${_getThaiStatus(_poStatus)})'
                      : 'สร้างใบรับสินค้า (Goods Receipt)',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (_poStatus == 'NEW' ||
                  _poStatus == 'DRAFT' ||
                  _poStatus == 'RECEIVED' ||
                  _poStatus == 'PARTIAL') ...[
                CustomButton(
                  onPressed: _createNewProduct,
                  icon: Icons.add_box,
                  label: 'สร้างสินค้าใหม่',
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(width: 10),
                CustomButton(
                  onPressed: _addProductToStockIn,
                  icon: Icons.add_shopping_cart,
                  label: 'เพิ่มสินค้า (F1)',
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ]
            ],
          ),
        ),

        // Header Row
        Container(
          decoration: BoxDecoration(
            color: Colors.indigo, // Use app primary color
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: const Row(
            children: [
              SizedBox(
                  width: 40,
                  child: Text('#',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 3,
                  child: Text('ชื่อสินค้า',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 1,
                  child: Text('จำนวน',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 1,
                  child: Text('หน่วย',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('ทุน/หน่วย',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 1,
                  child: Text('รวม',
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

        // List View
        Expanded(
          child: _stockInItems.isEmpty
              ? const Center(
                  child: Text('ยังไม่มีรายการสินค้า',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: _stockInItems.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = _stockInItems[index];
                    final unitName = _units
                        .firstWhere(
                          (u) => u.id == item.product.unitId,
                          orElse: () => Unit(id: 0, name: '-'),
                        )
                        .name;

                    return Container(
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? Colors.white
                            : Colors.indigo.withValues(alpha: 0.05),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text('${index + 1}')),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // ✏️ Edit Product Button
                                    InkWell(
                                      onTap: () => _editProductDetail(item),
                                      child: const Icon(Icons.edit_note,
                                          color: Colors.blue, size: 20),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(item.product.barcode ?? '-',
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '| ขาย: ${NumberFormat('#,##0.00').format(item.product.retailPrice)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: item.receivedQuantity > 0
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${NumberFormat('#,##0.##').format(item.receivedQuantity)} / ${NumberFormat('#,##0.##').format(item.quantity)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const Text(
                                          '(รับแล้ว)',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green),
                                        )
                                      ],
                                    )
                                  : CustomTextField(
                                      controller: item.qtyCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      onChanged: (val) => setState(() =>
                                          item.quantity =
                                              double.tryParse(val) ?? 0),
                                      selectAllOnFocus: true,
                                      enabled: _poStatus == 'NEW' ||
                                          _poStatus ==
                                              'DRAFT', // Disable edit if ORDERED/PARTIAL
                                    ),
                            ),
                          ),
                          Expanded(
                              flex: 1,
                              child:
                                  Text(unitName, textAlign: TextAlign.center)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: item.costCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    onChanged: (val) {
                                      setState(() => item.costPrice =
                                          double.tryParse(val) ?? 0);
                                    },
                                    selectAllOnFocus: true,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calculate,
                                      color: Colors.blue, size: 24),
                                  onPressed: () => _showCostCalculator(item),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                                NumberFormat('#,##0.00').format(item.total),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.indigo)),
                          ),
                          SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _stockInItems[index].dispose();
                                  _stockInItems.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final Supplier? selected = await showDialog<Supplier>(
                          context: context,
                          builder: (context) => const SupplierSearchDialog(),
                        );
                        if (selected != null) {
                          setState(() {
                            _selectedSupplierId = selected.id;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'ผู้ขาย',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixIcon: Icon(Icons.search),
                        ),
                        child: Text(
                          _suppliers
                              .firstWhere((s) => s.id == _selectedSupplierId,
                                  orElse: () =>
                                      Supplier(id: 0, name: '- เลือกผู้ขาย -'))
                              .name,
                          style: TextStyle(
                              color: _selectedSupplierId == null
                                  ? Colors.grey
                                  : Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // VAT Selection
                  Expanded(
                    flex: 1,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'ประเภทภาษี',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _vatType,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('รวมภาษี')),
                            DropdownMenuItem(value: 1, child: Text('แยกภาษี')),
                            DropdownMenuItem(
                                value: 2, child: Text('ไม่มีภาษี')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _vatType = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      controller: _docNoCtrl,
                      label: 'เลขที่เอกสาร',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ✅ VAT Calculation Display
              Builder(builder: (context) {
                final double subtotal =
                    _stockInItems.fold(0.0, (sum, item) => sum + item.total);
                double vatAmount = 0.0;
                if (_vatType == 1) {
                  // Excluded
                  vatAmount = subtotal * 0.07;
                } else if (_vatType == 0) {
                  // Included
                  // For display purposes, we might want to show how much VAT is inside?
                  // "Included" means GrandTotal = Entered Price.
                  // VAT = GrandTotal * 7 / 107
                  vatAmount = subtotal * 7 / 107;
                  // grandTotal remains subtotal (as entered)
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_vatType != 2) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                              _vatType == 0
                                  ? 'ยอดรวม (รวม VAT):'
                                  : 'ยอดรวมก่อนภาษี:',
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(NumberFormat('#,##0.00').format(subtotal),
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('ภาษีมูลค่าเพิ่ม (7%):',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Text(NumberFormat('#,##0.00').format(vatAmount),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                      const Divider(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'ยอดรวมสุทธิ: ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '฿${NumberFormat('#,##0.00').format(_totalCost)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
              const SizedBox(height: 10),

              // Action Buttons
              Row(
                children: [
                  if (_poStatus == 'NEW' || _poStatus == 'DRAFT') ...[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: CustomButton(
                          onPressed: () => _processAction('ORDERED'),
                          icon: Icons.save,
                          label: 'บันทึกใบสั่งซื้อ (ยังไม่เข้าสต็อก)',
                          type: ButtonType.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: CustomButton(
                        onPressed: _stockInItems.isEmpty
                            ? null
                            : () => _processAction('RECEIVED'),
                        icon: Icons.archive,
                        label: (_poStatus == 'RECEIVED')
                            ? 'บันทึกการแก้ไข'
                            : 'รับสินค้าเข้าสต็อก',
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase Order History Table (For Received Items)
// ---------------------------------------------------------------------------
class PurchaseOrderHistoryTable extends StatefulWidget {
  const PurchaseOrderHistoryTable({super.key});

  @override
  State<PurchaseOrderHistoryTable> createState() =>
      _PurchaseOrderHistoryTableState();
}

class _PurchaseOrderHistoryTableState extends State<PurchaseOrderHistoryTable> {
  final StockRepository _stockRepo = StockRepository();
  List<Map<String, dynamic>> _orders = [];

  bool _isLoading = false;

  // Filters
  DateTime? _selectedDate;
  int? _selectedSupplierId;
  String? _selectedSupplierName;

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
        // Filter by specific day (Start of day to End of day)
        startDate = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, 0, 0, 0);
        endDate = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, 23, 59, 59);
      }

      // Load RECEIVED only with filters
      final received = await _stockRepo.getPurchaseOrders(
        status: 'RECEIVED',
        startDate: startDate,
        endDate: endDate,
        supplierId: _selectedSupplierId,
      );

      if (mounted) {
        setState(() {
          _orders = received;
          // Sort by CreatedAt desc
          _orders.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
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
      });
      _loadData(); // Reload
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // 🔎 Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Date Filter
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
                    setState(() => _selectedDate = null);
                    _loadData();
                  },
                ),
              ],

              const SizedBox(width: 16),
              const VerticalDivider(),
              const SizedBox(width: 16),

              // Supplier Filter
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSupplier,
                  icon: const Icon(Icons.store),
                  label: Text(
                    _selectedSupplierId == null
                        ? 'ผู้ขาย: ทั้งหมด (All Suppliers)'
                        : 'ผู้ขาย: $_selectedSupplierName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // Match height of Date filter (default is usually ~40-48 depending on theme)
                    // If Date filter doesn't specify height, this one shouldn't need strict constraint either
                    // but we can wrap in SizedBox if needed.
                    // Previous container was height 40.
                  ),
                ),
              ),
              if (_selectedSupplierId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'ล้างผู้ขาย',
                  onPressed: () {
                    setState(() {
                      _selectedSupplierId = null;
                      _selectedSupplierName = null;
                    });
                    _loadData(); // Reload
                  },
                ),
              ],
            ],
          ),
        ),

        // List Content (if empty show message, else show list)
        if (_orders.isEmpty) ...[
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
                    flex: 2,
                    child: Text('ยอดรวม',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(width: 96), // แก้ไข + ลบ
              ],
            ),
          ),
          // List Body
          Expanded(
            child: ListView.separated(
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final order = _orders[i];
                final dt = DateTime.parse(order['createdAt'].toString());

                return InkWell(
                  onTap: () {
                    // View Details (Read Only Mode)
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
                    ).then((_) => _loadData()); // ✅ Refresh on return
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
                        // ── วันที่ + badge แก้ไข ──────────────────────────
                        Expanded(
                          flex: 2,
                          child: Builder(builder: (context) {
                            final updatedAtRaw = order['updatedAt'];
                            final createdAtRaw = order['createdAt'];
                            bool isModified = false;
                            String modifiedDateStr = '';
                            if (updatedAtRaw != null && createdAtRaw != null) {
                              try {
                                final updatedAt =
                                    DateTime.parse(updatedAtRaw.toString());
                                final createdAt =
                                    DateTime.parse(createdAtRaw.toString());
                                // ถือว่าแก้ไขถ้า updatedAt มากกว่า createdAt อย่างน้อย 2 วินาที
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
                                          Text(
                                            'ถูกแก้ไข',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
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
                            flex: 2,
                            child: Text(
                              NumberFormat('#,##0.00').format(double.tryParse(
                                      order['totalAmount'].toString()) ??
                                  0),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            )),
                        const SizedBox(width: 8),
                        // ── ปุ่มแก้ไข ────────────────────────────────────
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.indigo, size: 20),
                            onPressed: () => _editReceivedOrder(order),
                            tooltip: 'แก้ไขจำนวน',
                          ),
                        ),
                        // ── ปุ่มลบ ───────────────────────────────────────
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _deleteOrder(order),
                            tooltip: 'ลบและคืนสต็อก',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editReceivedOrder(Map<String, dynamic> order) async {
    final poId = int.tryParse(order['id'].toString()) ?? 0;
    if (poId == 0) return;

    // ดึงรายการสินค้าในใบรับเข้า
    List<Map<String, dynamic>> items = [];
    try {
      items = await _stockRepo.getPurchaseOrderItems(poId);
    } catch (e) {
      if (!mounted) return;
      AlertService.show(
          context: context,
          message: 'ไม่สามารถโหลดรายการสินค้าได้: $e',
          type: 'error');
      return;
    }

    if (!mounted) return;

    // เปิด Dialog แก้ไขจำนวน
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => _EditReceivedQtyDialog(
        poId: poId,
        orderRef: order['documentNo']?.toString() ?? '#$poId',
        items: items,
        vatType: int.tryParse(order['vatType']?.toString() ?? '0') ?? 0,
      ),
    );

    if (result == null || result.isEmpty) return;
    if (!mounted) return;

    // แสดง loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // คำนวณยอดรวมใหม่
      final vatType = int.tryParse(order['vatType']?.toString() ?? '0') ?? 0;
      double subtotal = result.fold(0.0, (s, item) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        return s + (qty * cost);
      });
      double totalWithVat = subtotal;
      if (vatType == 1) totalWithVat = subtotal * 1.07; // Excluded GST

      await _stockRepo.updateReceivedPurchaseOrderQty(
        poId: poId,
        newItems: result,
        totalAmount: totalWithVat,
        documentNo: order['documentNo']?.toString(),
        vatType: vatType,
      );

      if (!mounted) return;
      Navigator.pop(context); // ปิด loading
      _loadData(); // refresh list

      AlertService.show(
        context: context,
        message: 'แก้ไขรายการรับเข้าเรียบร้อยแล้ว',
        type: 'success',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ปิด loading
      AlertService.show(
        context: context,
        message: 'เกิดข้อผิดพลาดในการแก้ไข: $e',
        type: 'error',
      );
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
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
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CustomButton(
            label: 'ยืนยันลบ',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _stockRepo
            .deletePurchaseOrder(int.tryParse(order['id'].toString()) ?? 0);

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        // Refresh list
        _loadData();

        AlertService.show(
          context: context,
          message: 'ลบรายการสั่งซื้อเรียบร้อยแล้ว',
          type: 'success',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการลบ: $e',
          type: 'error',
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Edit Received PO Quantities Dialog
// ---------------------------------------------------------------------------
class _EditReceivedQtyDialog extends StatefulWidget {
  final int poId;
  final String orderRef;
  final List<Map<String, dynamic>> items;
  final int vatType;

  const _EditReceivedQtyDialog({
    required this.poId,
    required this.orderRef,
    required this.items,
    required this.vatType,
  });

  @override
  State<_EditReceivedQtyDialog> createState() => _EditReceivedQtyDialogState();
}

class _EditReceivedQtyDialogState extends State<_EditReceivedQtyDialog> {
  // controllers per item index
  late List<TextEditingController> _qtyControllers;
  late List<TextEditingController> _costControllers;

  @override
  void initState() {
    super.initState();
    _qtyControllers = widget.items.map((item) {
      final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
      return TextEditingController(
          text: qty.toString().replaceAll(RegExp(r'([.]*0+)(?!\d)'), ''));
    }).toList();

    _costControllers = widget.items.map((item) {
      final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
      return TextEditingController(
          text: cost.toString().replaceAll(RegExp(r'([.]*0+)(?!\d)'), ''));
    }).toList();
  }

  @override
  void dispose() {
    for (var c in _qtyControllers) {
      c.dispose();
    }
    for (var c in _costControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _calcSubtotal() {
    double total = 0.0;
    for (var i = 0; i < widget.items.length; i++) {
      final qty = double.tryParse(_qtyControllers[i].text) ?? 0.0;
      final cost = double.tryParse(_costControllers[i].text) ?? 0.0;
      total += qty * cost;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setStateDialog) {
      final subtotal = _calcSubtotal();
      double vatAmount = 0.0;
      double grandTotal = subtotal;
      if (widget.vatType == 0) {
        // รวมภาษี
        vatAmount = subtotal * 7 / 107;
      } else if (widget.vatType == 1) {
        // แยกภาษี
        vatAmount = subtotal * 0.07;
        grandTotal = subtotal + vatAmount;
      }

      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'แก้ไขจำนวนรับเข้า: ${widget.orderRef}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 750,
          height: 520,
          child: Column(
            children: [
              // ─── คำเตือน ───────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'การแก้ไขจะคืน Stock เดิม แล้วบันทึก Stock ใหม่ตามจำนวนที่แก้ไข',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text('สินค้า',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text('จำนวน',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text('ต้นทุน/หน่วย',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text('รวม',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ─── Items ─────────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final productName = item['productName']?.toString() ?? '-';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          // ชื่อสินค้า
                          Expanded(
                            flex: 4,
                            child: Text(
                              productName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // จำนวน
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _qtyControllers[index],
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.indigo.shade400,
                                      width: 1.5),
                                ),
                                hintText: '0',
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ต้นทุน
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _costControllers[index],
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.indigo.shade400,
                                      width: 1.5),
                                ),
                                hintText: '0.00',
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // รวม
                          Expanded(
                            flex: 2,
                            child: Builder(builder: (_) {
                              final qty = double.tryParse(
                                      _qtyControllers[index].text) ??
                                  0.0;
                              final cost = double.tryParse(
                                      _costControllers[index].text) ??
                                  0.0;
                              return Text(
                                NumberFormat('#,##0.00').format(qty * cost),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.indigo),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ─── สรุปยอด ────────────────────────────────────────────────────
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.vatType != 2) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.vatType == 0
                                ? 'ยอดรวม (รวม VAT):'
                                : 'ยอดรวมก่อนภาษี:',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            NumberFormat('#,##0.00').format(subtotal),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('ภาษีมูลค่าเพิ่ม (7%):',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Text(NumberFormat('#,##0.00').format(vatAmount),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('ยอดรวมสุทธิ:',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(
                          '฿${NumberFormat('#,##0.00').format(grandTotal)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
              // ตรวจสอบว่าจำนวนที่ใส่ถูกต้อง
              final List<Map<String, dynamic>> result = [];
              for (var i = 0; i < widget.items.length; i++) {
                final item = widget.items[i];
                final qty =
                    double.tryParse(_qtyControllers[i].text.trim()) ?? 0.0;
                final cost =
                    double.tryParse(_costControllers[i].text.trim()) ?? 0.0;

                if (qty < 0 || cost < 0) {
                  AlertService.show(
                    context: context,
                    message: 'จำนวนและต้นทุนต้องมากกว่าหรือเท่ากับ 0',
                    type: 'warning',
                  );
                  return;
                }

                result.add({
                  'productId': int.tryParse(item['productId'].toString()) ?? 0,
                  'productName': item['productName']?.toString() ?? '',
                  'quantity': qty,
                  'costPrice': cost,
                });
              }

              if (result.every((r) =>
                  (double.tryParse(r['quantity'].toString()) ?? 0.0) == 0)) {
                AlertService.show(
                  context: context,
                  message: 'จำนวนรับเข้าต้องมากกว่า 0 อย่างน้อย 1 รายการ',
                  type: 'warning',
                );
                return;
              }

              Navigator.pop(context, result);
            },
            label: 'บันทึกการแก้ไข',
            icon: Icons.save,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Partial Receive Dialog
// ---------------------------------------------------------------------------
class _PartialReceiveDialog extends StatefulWidget {
  final List<StockInItem> items;
  const _PartialReceiveDialog({required this.items});

  @override
  State<_PartialReceiveDialog> createState() => _PartialReceiveDialogState();
}

class _PartialReceiveDialogState extends State<_PartialReceiveDialog> {
  final Map<int, bool> _selected = {};
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, double> _remainingMap = {};

  @override
  void initState() {
    super.initState();
    for (var item in widget.items) {
      double remaining = item.quantity - item.receivedQuantity;
      if (remaining < 0) remaining = 0;

      // Default checked if there is remaining items
      bool autoSelect = remaining > 0;
      _selected[item.product.id] = autoSelect;
      _remainingMap[item.product.id] = remaining;

      // Default text = remaining (to receive all remaining)
      _qtyControllers[item.product.id] = TextEditingController(
          text:
              remaining.toString().replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), ""));
    }
  }

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เลือกรายการที่รับสินค้า (Partial Receive)'),
      content: SizedBox(
        width: 700, // Wider for columns
        height: 500,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 40), // Checkbox space
                  Expanded(
                      flex: 3,
                      child: Text('สินค้า',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text('สั่งซื้อ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                  Expanded(
                      child: Text('รับแล้ว',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green))),
                  Expanded(
                      child: Text('ค้างรับ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red))),
                  Expanded(
                      flex: 2,
                      child: Text('รับครั้งนี้',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo))),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isChecked = _selected[item.product.id] ?? false;
                  final remaining = _remainingMap[item.product.id] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          onChanged: remaining > 0
                              ? (val) {
                                  // Disable if 0 remaining? Maybe allow if over-receiving? Let's check logic.
                                  setState(() {
                                    _selected[item.product.id] = val ?? false;
                                  });
                                }
                              : null, // Disable check if completed
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(item.product.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: Text(
                              NumberFormat('#,##0.##').format(item.quantity),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                        ),
                        Expanded(
                          child: Text(
                              NumberFormat('#,##0.##')
                                  .format(item.receivedQuantity),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.green)),
                        ),
                        Expanded(
                          child: Text(
                              NumberFormat('#,##0.##').format(remaining),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              controller: _qtyControllers[item.product.id],
                              enabled: isChecked,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
            // Collect Data
            final List<Map<String, dynamic>> result = [];
            for (var item in widget.items) {
              if (_selected[item.product.id] == true) {
                final qtyStr = _qtyControllers[item.product.id]?.text ?? '0';
                final qty = double.tryParse(qtyStr) ?? 0;
                if (qty > 0) {
                  result.add({
                    'productId': item.product.id,
                    'productName': item.product.name,
                    'quantity': qty, // This is 'Receive Now' qty
                    'costPrice': item.costPrice,
                  });
                }
              }
            }

            if (result.isEmpty) {
              AlertService.show(
                  context: context,
                  message: 'กรุณาเลือกรายการที่จะรับสินค้า',
                  type: 'warning');
              return;
            }

            Navigator.pop(context, result);
          },
          label: 'ยืนยันการรับสินค้า',
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
