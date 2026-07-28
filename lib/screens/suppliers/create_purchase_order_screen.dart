import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart'; // ✅ Import Decimal
import '../../repositories/purchase_repository.dart';
import '../../repositories/product_repository.dart';
import '../../models/supplier.dart';
import '../../models/product.dart';
import '../products/widgets/product_search_dialog_for_select.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import 'supplier_search_dialog.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final PurchaseRepository _purchaseRepo = PurchaseRepository();

  Supplier? _selectedSupplier;
  final List<Map<String, dynamic>> _orderItems = [];

  bool _isLoading = false;
  String? _note;

  @override
  void initState() {
    super.initState();
  }

  void _addItem(Product product) {
    setState(() {
      // Check if already exists
      final index =
          _orderItems.indexWhere((item) => item['productId'] == product.id);

      // ✅ Use Decimal for internal values
      final Decimal cost = Decimal.parse(product.costPrice.toString());

      if (index >= 0) {
        // Increment quantity
        Decimal currentQty = _orderItems[index]['quantity'] as Decimal;
        Decimal newQty = currentQty + Decimal.one;
        Decimal currentCost = _orderItems[index]['costPrice'] as Decimal;

        _orderItems[index]['quantity'] = newQty;
        _orderItems[index]['total'] = newQty * currentCost;
      } else {
        _orderItems.add({
          'productId': product.id,
          'productName': product.name,
          'quantity': Decimal.one, // ✅ 1.0 -> Decimal
          'costPrice': cost,
          'total': cost, // 1 * cost
        });
      }
    });
  }

  // ✅ Computed property using Decimal
  Decimal get _totalAmount => _orderItems.fold(
      Decimal.zero, (sum, item) => sum + (item['total'] as Decimal));

  Future<void> _savePO() async {
    if (_selectedSupplier == null) {
      AlertService.show(
        context: context,
        message: 'กรุณาเลือกผู้จำหน่าย',
        type: 'warning',
      );
      return;
    }
    if (_orderItems.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณาเพิ่มรายการสินค้า',
        type: 'warning',
      );
      return;
    }

    setState(() => _isLoading = true);

    // ✅ Convert items back to double for Repository (API Contract)
    final List<Map<String, dynamic>> itemsForRepo = _orderItems.map((item) {
      return {
        'productId': item['productId'],
        'productName': item['productName'],
        'quantity': (item['quantity'] as Decimal).toDouble(),
        'costPrice': (item['costPrice'] as Decimal).toDouble(),
        'total': (item['total'] as Decimal).toDouble(),
      };
    }).toList();

    final poId = await _purchaseRepo.createPO(
      supplierId: _selectedSupplier!.id,
      branchId: 1, // Default. Future: Get from global state
      userId: null, // Future: Pass operator ID
      totalAmount:
          _totalAmount.toDouble(), // ✅ Convert Decimal to Double for Repo
      note: _note,
      items: itemsForRepo,
    );

    if (poId > 0 && mounted) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการสร้างใบสั่งซื้อ',
          type: 'error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างใบสั่งซื้อใหม่'),
        actions: [
          CustomButton(
            onPressed: _isLoading ? null : _savePO,
            icon: Icons.save,
            label: 'บันทึก PO',
            type: ButtonType.primary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 1. Supplier Selection
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final Supplier? s = await showDialog(
                              context: context,
                              builder: (ctx) => const SupplierSearchDialog(),
                            );
                            if (s != null) {
                              setState(() {
                                _selectedSupplier = s;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'ผู้จำหน่าย (Supplier)',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedSupplier?.name ?? 'คลิกเพื่อเลือกผู้จำหน่าย',
                                  style: TextStyle(
                                    color: _selectedSupplier == null ? Colors.grey : Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                                const Icon(Icons.search),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Search & Add Product
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: () async {
                            final Product? p = await showDialog(
                              context: context,
                              builder: (ctx) => ProductSearchDialogForSelect(
                                repo: ProductRepository(),
                              ),
                            );
                            if (p != null) _addItem(p);
                          },
                          icon: Icons.search,
                          label: 'ค้นหาและเพิ่มสินค้า',
                          type: ButtonType.primary,
                          backgroundColor: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Items List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8)),
                      child: _orderItems.isEmpty
                          ? const Center(
                              child: Text('ยังไม่มีสินค้าในรายการ',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: _orderItems.length,
                              separatorBuilder: (context, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final item = _orderItems[i];
                                // ✅ Extract as Decimals
                                final Decimal qty = item['quantity'] as Decimal;
                                final Decimal cost =
                                    item['costPrice'] as Decimal;

                                return ListTile(
                                  title: Text(item['productName']),
                                  subtitle: Row(
                                    children: [
                                      const Text('จำนวน: '),
                                      SizedBox(
                                        width: 60,
                                        child: CustomTextField(
                                          initialValue: qty
                                              .toString(), // Decimal.toString is clean (no .0 if int)
                                          keyboardType: TextInputType.number,
                                          onChanged: (val) {
                                            setState(() {
                                              // ✅ Parse new qty
                                              final newQty =
                                                  Decimal.tryParse(val) ??
                                                      Decimal.zero;
                                              item['quantity'] = newQty;
                                              item['total'] = newQty *
                                                  (item['costPrice']
                                                      as Decimal);
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text('ต้นทุน: '),
                                      SizedBox(
                                        width: 80,
                                        child: CustomTextField(
                                          initialValue: cost.toString(),
                                          keyboardType: TextInputType.number,
                                          onChanged: (val) {
                                            setState(() {
                                              // ✅ Parse new cost
                                              final newCost =
                                                  Decimal.tryParse(val) ??
                                                      Decimal.zero;
                                              item['costPrice'] = newCost;
                                              item['total'] = (item['quantity']
                                                      as Decimal) *
                                                  newCost;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          '${nf.format((item['total'] as Decimal).toDouble())} ฿',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => setState(
                                            () => _orderItems.removeAt(i)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Totals
                  Card(
                    color: Colors.indigo.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ยอดรวมทั้งหมด:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                              '${nf.format(_totalAmount.toDouble())} ฿', // ✅ Convert to Double for Display
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
