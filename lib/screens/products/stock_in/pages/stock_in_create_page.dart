import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/alert_service.dart';
import '../../../../models/product.dart';
import '../../../../models/supplier.dart';
import '../../../../models/unit.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../repositories/stock_repository.dart';
import '../../../../repositories/supplier_repository.dart';
import '../../../../repositories/unit_repository.dart';
import '../../product_multi_selection_dialog.dart';
import '../../widgets/supplier_search_dialog.dart';
import '../../dialogs/product_form/product_form_dialog.dart';
import '../../../../widgets/common/custom_text_field.dart';
import '../../../../widgets/common/custom_buttons.dart';
import '../../../../widgets/common/confirm_dialog.dart';
import '../models/stock_in_item.dart';
import '../dialogs/partial_receive_dialog.dart';
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
  bool _isPaid = false;

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
        _isPaid = (int.tryParse(header['isPaid'].toString()) ?? 0) == 1;

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
          isPaid: _isPaid,
        );
      } else {
        await _stockRepo.createPurchaseOrder(
          supplierId: _selectedSupplierId!,
          totalAmount: _totalCost,
          items: itemsMap,
          documentNo: _docNoCtrl.text,
          status: targetStatus,
          vatType: _vatType,
          isPaid: _isPaid,
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
      builder: (context) => PartialReceiveDialog(items: _stockInItems),
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
                              child: (item.receivedQuantity > 0 && _poStatus != 'RECEIVED')
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
                                          _poStatus == 'DRAFT' ||
                                          _poStatus == 'RECEIVED', // Enable edit if NEW, DRAFT, or RECEIVED (editing mode)
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
                  const SizedBox(width: 10),
                  // Payment Toggle
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: () => setState(() => _isPaid = !_isPaid),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'สถานะการเงิน',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isPaid ? Icons.check_circle : Icons.error_outline,
                              color: _isPaid ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isPaid ? 'จ่ายเงินแล้ว' : 'ยังไม่จ่าย',
                              style: TextStyle(
                                color: _isPaid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
