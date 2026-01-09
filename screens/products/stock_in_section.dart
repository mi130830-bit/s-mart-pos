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

import 'product_selection_dialog.dart';
import 'widgets/supplier_search_dialog.dart';
import 'product_list_view.dart'; // For ProductFormDialog
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

class StockInItem {
  final Product product;
  double quantity;
  double costPrice;
  int vatType;

  StockInItem({
    required this.product,
    required this.quantity,
    required this.costPrice,
    this.vatType = 0,
  });

  double get total => quantity * costPrice;
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
                    if (val == true) {
                      setState(() {});
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
      // Load DRAFT and ORDERED
      final drafts = await _stockRepo.getPurchaseOrders(status: 'DRAFT');
      final ordered = await _stockRepo.getPurchaseOrders(status: 'ORDERED');
      setState(() {
        _orders = [...drafts, ...ordered];
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
              backgroundColor:
                  status == 'DRAFT' ? Colors.grey[200] : Colors.orange[100],
              child: Icon(
                status == 'DRAFT' ? Icons.edit_note : Icons.local_shipping,
                color: status == 'DRAFT' ? Colors.grey : Colors.orange,
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
                    color: status == 'DRAFT' ? Colors.grey : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Column(
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
            onTap: () async {
              // Open to Receive or Edit
              final bool? result = await Navigator.push(
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
              if (result == true) {
                _loadData(); // Refresh list
                widget.onRefresh?.call();
              }
            },
          ),
        );
      },
    );
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
    // This is a simplified load. Getting full header info usually requires a specific method.
    // Re-using getPurchaseOrders or querying DB in Repo is best.
    // For now, let's assume we fetch items and map status.
    final items = await _stockRepo.getPurchaseOrderItems(poId);
    final headerList = await _stockRepo.getPurchaseOrders(
        status:
            null); // This is inefficient for 1 item but ok for now or we add getPOById
    // Filter for our ID
    final matching =
        headerList.where((e) => e['id'].toString() == poId.toString()).toList();

    if (matching.isEmpty) return;

    final header = matching.first;

    if (header.isNotEmpty) {
      _selectedSupplierId = int.tryParse(header['supplierId'].toString());
      _docNoCtrl.text = header['documentNo'] ?? '';
      _poStatus = header['status'] ?? 'NEW';

      // Load products for items
      for (var item in items) {
        final p = await _productRepo
            .getProductById(int.tryParse(item['productId'].toString()) ?? 0);
        if (p != null) {
          _stockInItems.add(StockInItem(
              product: p,
              quantity: double.tryParse(item['quantity'].toString()) ?? 0,
              costPrice: double.tryParse(item['costPrice'].toString()) ?? 0,
              vatType: p.vatType // fallback
              ));
        }
      }
    }
  }

  Future<void> _addProductToStockIn() async {
    // final products = await _productRepo.getAllProducts(); // Optimized: Load inside dialog
    if (!mounted) return;

    final Product? picked = await showDialog<Product>(
      context: context,
      builder: (context) => ProductSelectionDialog(repo: _productRepo),
    );

    if (picked != null) {
      final existingIndex = _stockInItems.indexWhere(
        (i) => i.product.id == picked.id,
      );
      if (existingIndex >= 0) {
        setState(() {
          _stockInItems[existingIndex].quantity += 1;
        });
      } else {
        setState(() {
          _stockInItems.add(
            StockInItem(
              product: picked,
              quantity: 1,
              costPrice: picked.costPrice,
              vatType: picked.vatType,
            ),
          );
        });
      }
    }
  }

  Future<void> _createNewProduct() async {
    final Product? newProduct = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductFormDialog(repo: _productRepo),
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
                    setState(() => item.costPrice = calculateCostPerUnit());
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

    // Confirmation
    final bool? confirm = await ConfirmDialog.show(
      context,
      title: targetStatus == 'RECEIVED'
          ? 'ยืนยันการรับเข้าสินค้า?'
          : 'บันทึกใบสั่งซื้อ?',
      content: targetStatus == 'RECEIVED'
          ? 'สินค้าจะถูกเพิ่มเข้าสต็อกทันทีและราคาทุนจะถูกอัปเดต'
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

      // String note = ''; // Unused variable removed

      if (widget.existingPoId != null) {
        // Handle Existing PO: Update & Receive (or Update only)
        await _stockRepo.updatePurchaseOrder(
          poId: widget.existingPoId!,
          totalAmount: _totalCost,
          items: itemsMap,
          documentNo: _docNoCtrl.text,
          status: targetStatus, // 'ORDERED' or 'RECEIVED'
        );
      } else {
        await _stockRepo.createPurchaseOrder(
          supplierId: _selectedSupplierId!,
          totalAmount: _totalCost,
          items: itemsMap,
          documentNo: _docNoCtrl.text,
          status: targetStatus, // DRAFT, ORDERED, RECEIVED
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context, true); // Close screen & refresh

        AlertService.show(
          context: context,
          message: targetStatus == 'RECEIVED'
              ? 'รับเข้าสินค้าเรียบร้อย'
              : 'บันทึกใบสั่งซื้อเรียบร้อย',
          type: 'success',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    }
  }

  double get _totalCost =>
      _stockInItems.fold(0.0, (sum, item) => sum + item.total);

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
                      ? 'จัดการใบสั่งซื้อ #${widget.existingPoId} ($_poStatus)'
                      : 'สร้างใบรับสินค้า (Goods Receipt)',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (_poStatus == 'NEW' || _poStatus == 'DRAFT') ...[
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
                                Text(item.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(item.product.barcode ?? '-',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: CustomTextField(
                                initialValue: item.quantity.toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                onChanged: (val) => setState(() =>
                                    item.quantity = double.tryParse(val) ?? 0),
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
                                    key: ValueKey(item.costPrice),
                                    initialValue: item.costPrice
                                        .toStringAsFixed(4)
                                        .replaceAll(
                                            RegExp(r"([.]*0+)(?!.*\d)"), ""),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    onChanged: (val) => setState(() => item
                                        .costPrice = double.tryParse(val) ?? 0),
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
                              onPressed: () =>
                                  setState(() => _stockInItems.removeAt(index)),
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
                          labelText: 'ผู้ขาย (กดเพื่อค้นหา)',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: Icon(Icons.arrow_drop_down),
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
                  Expanded(
                    child: CustomTextField(
                      controller: _docNoCtrl,
                      label: 'เลขที่เอกสาร / PO',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                        label: 'รับสินค้าเข้าสต็อก (Receive Now)',
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load RECEIVED only
      final received = await _stockRepo.getPurchaseOrders(status: 'RECEIVED');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('ไม่มีประวัติการรับเข้า',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
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
              SizedBox(width: 50), // For View Action
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
                            existingPoId: int.tryParse(order['id'].toString())),
                      ),
                    ),
                  );
                },
                child: Container(
                  color: i % 2 == 0
                      ? Colors.white
                      : Colors.indigo.withValues(alpha: 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 50,
                          child: Text('${i + 1}',
                              style: const TextStyle(color: Colors.grey))),
                      Expanded(
                          flex: 2,
                          child:
                              Text(DateFormat('dd/MM/yyyy HH:mm').format(dt))),
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
                      const SizedBox(
                        width: 50,
                        child: Icon(Icons.visibility,
                            color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
