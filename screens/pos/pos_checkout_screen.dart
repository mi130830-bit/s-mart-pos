import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart'; // ✅ Added back Decimal import

import 'package:intl/intl.dart';
import 'dart:async';

import '../../models/product.dart';
import '../../models/customer.dart';
import '../../repositories/product_repository.dart';
import '../../state/auth_provider.dart';

import '../products/product_list_view.dart';
import '../products/widgets/product_search_dialog_for_select.dart';
import '../products/widgets/quick_menu_dialog.dart';
import '../../models/order_item.dart'; // ✅ Added Import
// import '../../services/sales/cart_service.dart';
// import '../../services/sales/held_bill_manager.dart';
// import '../../services/sales/order_processing_service.dart';
import '../../services/printing/receipt_service.dart'; // ✅ Added Import
import '../../services/alert_service.dart';
// import '../../services/online_product_lookup_service.dart'; // ✅ Added Import
import 'payment_modal.dart';
import 'pos_state_manager.dart';
import 'pos_control_bar.dart';
import 'pos_cart_list.dart';
import 'pos_payment_panel.dart';
import '../../utils/barcode_utils.dart';
// import '../../services/alert_service.dart';
// import '../../services/online_product_lookup_service.dart'; // ✅ Added Import
import '../customers/customer_search_dialog.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/barcode_listener_wrapper.dart'; // ✅ Added Import

class PosCheckoutScreen extends StatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocus = FocusNode(); // ✅ Added Focus Guard
  bool _isLoading = false; // ✅ Added for Overlay

  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  final ProductRepository _productRepo = ProductRepository();
  // ❌ ลบออก: _productsFuture (ไม่ต้องโหลดสินค้าทั้งหมด)

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // ❌ ลบออก: getAllProducts() call
    _barcodeCtrl.addListener(_onBarcodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeCtrl.removeListener(_onBarcodeChanged);
    _barcodeCtrl.removeListener(_onBarcodeChanged);
    _barcodeFocusNode.dispose();
    _keyboardListenerFocus.dispose(); // ✅ Dispose
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  bool _checkPermission(String key, String actionName) {
    if (!mounted) return false;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.hasPermission(key)) return true;

    ConfirmDialog.show(
      context,
      title: 'ไม่มีสิทธิ์เข้าถึง',
      content: 'คุณไม่มีสิทธิ์: $actionName',
      confirmText: 'ตกลง',
      isDestructive: false,
    );
    return false;
  }

  void _resetTransaction() async {
    if (!_checkPermission('void_bill', 'ยกเลิกบิล (Clear Bill)')) return;

    final posState = Provider.of<PosStateManager>(context, listen: false);
    await posState.clearCart(returnStock: true);
    posState.selectCustomer(null);
    _qtyCtrl.text = '1';
    _barcodeFocusNode.requestFocus();
    if (mounted) {
      AlertService.show(
        context: context,
        message: 'เริ่มรายการใหม่เรียบร้อย',
        type: 'warning',
      );
    }
  }

  void _showCustomerDialog(PosStateManager posState) async {
    final customer = await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CustomerSearchDialog(),
    );
    if (customer != null) {
      posState.selectCustomer(customer);
    }
    _barcodeFocusNode.requestFocus();
  }

  void _openPaymentModal() async {
    final posState = Provider.of<PosStateManager>(context, listen: false);
    if (posState.cart.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentModal(onPaymentSuccess: _resetTransaction),
    );

    if (result == true) {
      if (!mounted) return;
      final posState = Provider.of<PosStateManager>(context, listen: false);

      // ✅ 1. Snapshot items before clearing
      final cartSnapshot = List<OrderItem>.from(posState.cart);

      bool isCredit =
          posState.lastPaymentMethod.toLowerCase().contains('credit') ||
              posState.lastPaymentMethod.contains('เงินเชื่อ');

      //  Loading Overlay logic (simulated or real?)
      //  Ideally saveOrder is called IN Modal, so here we just handle post-success.
      //  If Modal returns true, it means success.

      await posState.clearCart(returnStock: false);
      posState.selectCustomer(null);

      if (mounted) {
        AlertService.show(
          context: context,
          message: isCredit ? '📝 บันทึกลงบัญชีสำเร็จ' : '💵 ชำระเงินสำเร็จ',
          type: isCredit ? 'warning' : 'success',
          duration: const Duration(seconds: 2),
        );

        // ✅ 2. Check for Front Store Items (Non-Warehouse)
        final frontItems = cartSnapshot.where((i) {
          final isWarehouse = i.product?.isWarehouseItem ?? false;
          return !isWarehouse;
        }).toList();

        if (frontItems.isNotEmpty) {
          // Add a small delay for UX so alert can be seen
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showFrontStoreChecklist(frontItems);
          });
        }
      }
    } else {
      _barcodeFocusNode.requestFocus();
    }
  }

  bool _isProcessing = false; // ✅ Prevent Double Submission

  void _onBarcodeChanged() {
    final text = _barcodeCtrl.text;
    if (text.isEmpty) return;

    // Fix Thai Input instantly while typing
    final normalized = BarcodeUtils.fixThaiInput(text);
    if (normalized != text) {
      _barcodeCtrl.text = normalized;
      _barcodeCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _barcodeCtrl.text.length));
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    // ✅ Reduce waiting time for manual typing (was 600ms)
    // 300ms is enough for human typing, scanner usually sends Enter anyway.
    if (normalized.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final currentText = _barcodeCtrl.text;
        if (currentText.isNotEmpty && !_isProcessing) {
          final posState = Provider.of<PosStateManager>(context, listen: false);
          _handleBarcodeSubmit(currentText, posState);
        }
      });
    }
  }

  // ✅ New Logic: Search via State Manager
  void _handleBarcodeSubmit(String value, PosStateManager posState) async {
    // 1. Cancel any pending timer IMMEDIATELY
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      _barcodeFocusNode.requestFocus();
      return;
    }

    // 2. Prevent Double Submission
    if (_isProcessing) return;
    _isProcessing = true; // 🔒 Lock
    setState(() => _isLoading = true); // ✅ Show Loading Overlay

    try {
      double quantity = double.tryParse(_qtyCtrl.text) ?? 1.0;
      if (quantity <= 0) quantity = 1.0;

      // Call State Manager
      final result = await posState.handleBarcode(value, quantity: quantity);

      if (!mounted) return;

      switch (result.status) {
        case ScanStatus.success:
          _barcodeCtrl.clear();
          setState(() => _qtyCtrl.text = '1');

          // Show Feedback
          if (result.product != null) {
            AlertService.show(
              context: context,
              message:
                  'เพิ่ม ${result.product!.name} x${NumberFormat('#,##0').format(quantity)} แล้ว',
              type: 'success',
              duration: const Duration(seconds: 1),
            );

            // Stock Low Check
            if (result.product!.trackStock &&
                result.product!.stockQuantity <=
                    (result.product!.reorderPoint ?? 0)) {
              // Delayed warning
              Future.delayed(const Duration(milliseconds: 1200), () {
                if (mounted) {
                  AlertService.show(
                      context: context,
                      message:
                          '⚠️ สินค้าใกล้หมด: ${result.product!.name} (คงเหลือ: ${result.product!.stockQuantity})',
                      type: 'warning',
                      duration: const Duration(seconds: 3));
                }
              });
            }
          }
          break;

        case ScanStatus.multipleMatches:
          if (result.matches != null && result.matches!.isNotEmpty) {
            _showValidationMoreThanOne(result.matches!, quantity, posState);
          }
          break;

        case ScanStatus.notFound:
          _barcodeCtrl.clear();
          _showNotFoundDialog(value, posState, quantity);
          break;

        case ScanStatus.error:
          AlertService.show(
            context: context,
            message: result.message ?? 'Error scanning info',
            type: 'error',
          );
          break;

        case ScanStatus.requiresWeight:
          if (result.product != null) {
            _showWeighingDialog(result.product!, posState);
          }
          break;
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted && msg.contains('สต๊อกสินค้า')) {
        // Stock check failed — the exception has the product name & available qty
        AlertService.show(context: context, message: msg, type: 'warning');
      } else {
        debugPrint('Scan Error: $e');
        AlertService.show(
            context: context, message: 'Scan Error: $e', type: 'error');
      }
    } finally {
      // 3. Unlock ALWAYS
      if (mounted) setState(() => _isLoading = false); // ✅ Hide Loading Overlay
      _isProcessing = false;
      _barcodeFocusNode.requestFocus();
    }
  }

  // Removed _addToCartWithFeedback as logic is now handled in callback loop
  // But we reused some logic in switch-case above.
  // We can delete this method or keep it private if used by dialogs.
  // Dialogs use it. Let's redirect calls to handleBarcode or keep simpler version.

  // Re-implementing simplified version for Dialogs to use (direct add):
  Future<void> _addToCartWithFeedback(
      Product product, double quantity, PosStateManager posState,
      {double? overridePrice,
      String? overrideUnit,
      double? overrideConversionFactor,
      bool refocus = true}) async {
    try {
      await posState.addProductToCart(product,
          quantity: quantity,
          overridePrice: overridePrice,
          overrideUnit: overrideUnit,
          overrideConversionFactor: overrideConversionFactor);

      _barcodeCtrl.clear();
      setState(() => _qtyCtrl.text = '1');

      if (mounted) {
        AlertService.show(
          context: context,
          message:
              'เพิ่ม ${product.name} x${NumberFormat('#,##0').format(quantity)} แล้ว',
          type: 'success',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted && msg.contains('สต๊อกสินค้า')) {
        _showStockInsufficientDialog(msg, product, posState,
            overridePrice: overridePrice,
            overrideUnit: overrideUnit,
            overrideConversionFactor: overrideConversionFactor);
      } else if (mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาด: $e',
          type: 'error',
        );
      }
    }
    if (refocus) _barcodeFocusNode.requestFocus();
  }

  // ✅ Stock Insufficient Dialog
  void _showStockInsufficientDialog(String errorMsg, Product product,
      PosStateManager posState,
      {double? overridePrice,
      String? overrideUnit,
      double? overrideConversionFactor}) {
    // Parse available stock from error message
    // Format: 'สต๊อกสินค้า "..." ไม่พอ (เหลือ: X ชิ้น, ต้องการ: Y ชิ้น)'
    double availableQty = 0;
    try {
      final match = RegExp(r'เหลือ: (\d+\.?\d*) ชิ้น').firstMatch(errorMsg);
      if (match != null) availableQty = double.tryParse(match.group(1)!) ?? 0;
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('สต็อกไม่พอ!', style: TextStyle(color: Colors.orange)),
          ],
        ),
        content: Text(
          'สินค้า "${product.name}" คงเหลือเพียง ${availableQty.toStringAsFixed(0)} ชิ้น เท่านั้น\n\nต้องการเพิ่ม ${availableQty.toStringAsFixed(0)} ชิ้น (เท่าที่มี) หรือยกเลิก?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          if (availableQty > 0)
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text('เพิ่ม ${availableQty.toStringAsFixed(0)} ชิ้น'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await posState.addProductToCart(product,
                    quantity: availableQty,
                    overridePrice: overridePrice,
                    overrideUnit: overrideUnit,
                    overrideConversionFactor: overrideConversionFactor);
                _barcodeCtrl.clear();
                setState(() => _qtyCtrl.text = '1');
                if (mounted) {
                  AlertService.show(
                    context: context,
                    message:
                        'เพิ่ม ${product.name} x${availableQty.toStringAsFixed(0)} ชิ้น (เท่าที่มีในสต็อก)',
                    type: 'warning',
                    duration: const Duration(seconds: 2),
                  );
                }
              },
            ),
        ],
      ),
    ).then((_) => _barcodeFocusNode.requestFocus());
  }

  void _showValidationMoreThanOne(
      List<Product> matches, double quantity, PosStateManager posState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('พบสินค้า ${matches.length} รายการ'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final p = matches[i];
              return ListTile(
                leading: const Icon(Icons.qr_code),
                title: Text(p.name),
                subtitle: Text('${p.barcode} | ฿${p.retailPrice}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addToCartWithFeedback(p, quantity, posState);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _barcodeFocusNode.requestFocus();
              },
              child: const Text('ยกเลิก'))
        ],
      ),
    ).then((_) {
      _barcodeCtrl.clear();
      _barcodeFocusNode.requestFocus();
    });
  }

  void _showNotFoundDialog(
      String barcode, PosStateManager posState, double qty) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BarcodeListenerWrapper(
        onBarcodeScanned: (newBarcode) {
          debugPrint('🚀 [Seamless Scan] Dialog intercepted: $newBarcode');
          Navigator.pop(ctx);
          // Small delay to let dialog close before processing new code
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _handleBarcodeSubmit(newBarcode, posState);
            }
          });
        },
        child: AlertDialog(
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 30),
            const SizedBox(width: 10),
            Expanded(
                child: Text('ไม่พบสินค้า: $barcode',
                    style: const TextStyle(fontSize: 18))),
          ]),
          content: const Text(
              'คุณต้องการทำรายการอย่างไร?\n(หรือสแกนสินค้าชิ้นถัดไปได้เลย)',
              style: TextStyle(fontSize: 16)),
          actions: [
            CustomButton(
              icon: Icons.add_circle,
              label: 'ลงทะเบียนสินค้าใหม่',
              backgroundColor: Colors.purple,
              onPressed: () {
                if (!_checkPermission(
                    'manage_product', 'ลงทะเบียนสินค้าใหม่')) {
                  return;
                }
                Navigator.pop(ctx);
                _openCreateProductDialog(barcode, posState, qty);
              },
            ),
            CustomButton(
              icon: Icons.sell,
              label: 'ขายระบุราคาเอง',
              backgroundColor: Colors.green,
              onPressed: () {
                if (!_checkPermission('sale', 'ขายสินค้า')) return;
                Navigator.pop(ctx);
                _showQuickSaleDialog(barcode, posState, qty);
              },
            ),
            CustomButton(
              label: 'ยกเลิก',
              type: ButtonType.secondary,
              onPressed: () {
                Navigator.pop(ctx);
                _barcodeFocusNode.requestFocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateProductDialog(
      String barcode, PosStateManager posState, double qty,
      {Map<String, dynamic>? onlineData}) async {
    final tempProduct = Product(
        id: 0,
        name: onlineData != null ? onlineData['name'] : '',
        barcode: barcode,
        retailPrice: 0,
        costPrice: 0,
        productType: 0,
        trackStock: true,
        stockQuantity: 0,
        points: 0);

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          ProductFormDialog(repo: _productRepo, product: tempProduct),
    );

    if (result != null) {
      final matches =
          await _productRepo.getProductsPaginated(1, 1, searchTerm: barcode);
      if (matches.isNotEmpty) {
        final newProductMatch = matches.first;
        await posState.addProductToCart(newProductMatch, quantity: qty);
        if (mounted) {
          AlertService.show(
            context: context,
            message: 'ลงทะเบียนและเพิ่ม "${newProductMatch.name}" แล้ว',
            type: 'success',
          );
        }
        _qtyCtrl.text = '1';
        _barcodeFocusNode.requestFocus();
      }
    } else {
      _barcodeFocusNode.requestFocus();
    }
  }

  // _showQuickSaleDialog, _showSearchDialog, _showQuickMenuDialog, _showEditItemDialog
  // (Logic remains same as original but _productsFuture is gone, which is fine)

  // Only displaying changed parts above for brevity.
  // Restore rest of the file logic (QuickSale, etc) as it doesn't depend on _productsFuture.

  void _showQuickSaleDialog(
      String barcode, PosStateManager posState, double qty) {
    // ... (Same as original)
    final priceCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'สินค้าทั่วไป ($barcode)');

    Future<void> onConfirm() async {
      final price = double.tryParse(priceCtrl.text) ?? 0;
      if (price > 0) {
        final tempProduct = Product(
            id: -999,
            name: nameCtrl.text,
            barcode: barcode,
            retailPrice: price,
            costPrice: 0,
            productType: 0,
            stockQuantity: 0,
            trackStock: false,
            points: 0);
        await posState.addProductToCart(tempProduct, quantity: qty);
        if (mounted) Navigator.pop(context);
        _qtyCtrl.text = '1';
        _barcodeFocusNode.requestFocus();
      }
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('ขายสินค้าชั่วคราว'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: nameCtrl,
                    label: 'ชื่อสินค้า',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: priceCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    label: 'ราคาขาย',
                    selectAllOnFocus: true, // ✅ Auto-select
                    onSubmitted: (_) => onConfirm(),
                  ),
                ],
              ),
              actions: [
                CustomButton(
                    label: 'ยกเลิก',
                    type: ButtonType.secondary,
                    onPressed: () => Navigator.pop(ctx)),
                CustomButton(label: 'ยืนยัน', onPressed: onConfirm),
              ],
            )).then((_) => _barcodeFocusNode.requestFocus());
  }

  void _showSearchDialog(PosStateManager posState) async {
    final selected = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductSearchDialogForSelect(repo: _productRepo),
    );
    if (selected != null) {
      double quantity = double.tryParse(_qtyCtrl.text) ?? 1.0;
      await _addToCartWithFeedback(selected, quantity, posState);
    }
    _barcodeFocusNode.requestFocus();
  }

  void _showQuickMenuDialog(PosStateManager posState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuickMenuDialog(
        productRepo: _productRepo,
        onProductSelected: (product) async {
          double quantity = double.tryParse(_qtyCtrl.text) ?? 1.0;
          await _addToCartWithFeedback(product, quantity, posState,
              refocus: false); // ✅ Maintain Focus in Dialog
        },
      ),
    );
  }

  void _showWeighingDialog(Product product, PosStateManager posState) {
    final weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ระบุน้ำหนัก: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: weightCtrl,
              label: 'น้ำหนัก (kg)',
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) {
                final w = double.tryParse(weightCtrl.text) ?? 0;
                if (w > 0) {
                  Navigator.pop(ctx);
                  _addToCartWithFeedback(product, w, posState);
                }
              },
            ),
          ],
        ),
        actions: [
          CustomButton(
              label: 'ยกเลิก',
              type: ButtonType.secondary,
              onPressed: () => Navigator.pop(ctx)),
          CustomButton(
              label: 'ยืนยัน',
              onPressed: () {
                final w = double.tryParse(weightCtrl.text) ?? 0;
                if (w > 0) {
                  Navigator.pop(ctx);
                  _addToCartWithFeedback(product, w, posState);
                }
              }),
        ],
      ),
    ).then((_) => _barcodeFocusNode.requestFocus());
  }

  void _showEditItemDialog(PosStateManager posState, int index) {
    final item = posState.cart[index];
    // Qty & Price now editable in list directly, but user wants them back here too
    final qtyCtrl = TextEditingController(
        text: NumberFormat('#.##').format(item.quantity.toDouble()));
    final priceCtrl = TextEditingController(
        text: NumberFormat('#.##').format(item.price.toDouble()));
    final qtyFocus = FocusNode();
    final priceFocus = FocusNode();
    final discountCtrl = TextEditingController(text: '0');
    final commentCtrl = TextEditingController(text: item.comment);
    int discountMode = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, st) {
          Future<void> saveAction() async {
            // 1. Update Qty
            final newQty = Decimal.tryParse(qtyCtrl.text);
            if (newQty != null && newQty != item.quantity) {
              await posState.updateItemQuantity(index, newQty);
            }

            // 2. Update Price
            final newPrice = Decimal.tryParse(priceCtrl.text);
            if (newPrice != null && newPrice != item.price) {
              // Permission check for price
              if (!posState.allowPriceEdit) {
                if (!_checkPermission('price_edit', 'แก้ไขราคา')) return;
              }
              await posState.updateItemPrice(index, newPrice);
            }

            // Only Discount & Comment
            double inputVal = double.tryParse(discountCtrl.text) ?? 0;
            if (inputVal >= 0) {
              if (inputVal > 0 &&
                  !_checkPermission('pos_discount', 'ให้ส่วนลด')) {
                return; // Check only if discount > 0
              }

              if (index < posState.cart.length) {
                double finalDiscount = 0.0;
                final currentItem = posState.cart[index];
                if (discountMode == 0) {
                  finalDiscount = inputVal * currentItem.quantity.toDouble();
                } else if (discountMode == 1) {
                  finalDiscount = inputVal;
                } else if (discountMode == 2) {
                  finalDiscount = (currentItem.price.toDouble() *
                          currentItem.quantity.toDouble()) *
                      (inputVal / 100);
                }

                // Only update if discount changed or is valid
                if (finalDiscount > 0 || currentItem.discount > Decimal.zero) {
                  posState.updateItemDiscount(index, finalDiscount,
                      isPercent: false);
                }
              }
            }

            if (commentCtrl.text != item.comment) {
              posState.updateItemComment(index, commentCtrl.text);
            }

            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          }

          return AlertDialog(
            title: Text('แก้ไข: ${item.productName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Restore Qty & Price Fields per user request
                  // ✅ Restore Qty & Price Fields stacked vertically
                  CustomTextField(
                    controller: qtyCtrl,
                    focusNode: qtyFocus,
                    label: 'จำนวน (Qty)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    selectAllOnFocus: true, // ✅ Auto-select
                    onTap: () => qtyCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: qtyCtrl.text.length),
                    onSubmitted: (_) => priceFocus.requestFocus(),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: priceCtrl,
                    focusNode: priceFocus,
                    label: 'ราคาต่อหน่วย (Price)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    selectAllOnFocus: true, // ✅ Auto-select
                    onTap: () => priceCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: priceCtrl.text.length),
                    onSubmitted: (_) => saveAction(),
                  ),
                  const SizedBox(height: 10),
                  const Text('ส่วนลด (Discount):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Center(
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected: [
                        discountMode == 0,
                        discountMode == 1,
                        discountMode == 2
                      ],
                      onPressed: (int newIndex) =>
                          st(() => discountMode = newIndex),
                      children: const [
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ต่อชิ้น')),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('รวม')),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('%'))
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    label: discountMode == 2
                        ? 'เปอร์เซ็นต์ (%)'
                        : 'จำนวนเงิน (บาท)',
                    selectAllOnFocus: true, // ✅ Auto-select
                    onTap: () => discountCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: discountCtrl.text.length),
                    onSubmitted: (_) => saveAction(),
                  ),
                  const SizedBox(height: 10),
                  const Text('หมายเหตุ (Comment):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  CustomTextField(
                    controller: commentCtrl,
                    hint: 'ระบุหมายเหตุสินค้า (ถ้ามี)',
                    onSubmitted: (_) => saveAction(),
                  ),
                ],
              ),
            ),
            actions: [
              CustomButton(
                  label: 'ยกเลิก',
                  type: ButtonType.secondary,
                  onPressed: () => Navigator.pop(ctx)),
              CustomButton(
                label: 'บันทึก',
                onPressed: saveAction,
              ),
            ],
          );
        },
      ),
    ).then((_) => _barcodeFocusNode.requestFocus());
  }

  void _showQuantityDialog() {
    final inputCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ระบุจำนวนสินค้า (Quantity)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: inputCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              label: 'จำนวน',
              hint: 'เช่น 2, 5, 10',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              onSubmitted: (_) {
                Navigator.pop(ctx);
                _applyQuantity(inputCtrl.text);
              },
            ),
          ],
        ),
        actions: [
          CustomButton(
              label: 'ยกเลิก',
              type: ButtonType.secondary,
              onPressed: () => Navigator.pop(ctx)),
          CustomButton(
              label: 'ตกลง',
              onPressed: () {
                Navigator.pop(ctx);
                _applyQuantity(inputCtrl.text);
              }),
        ],
      ),
    ).then((_) => _barcodeFocusNode.requestFocus());
  }

  void _applyQuantity(String val) {
    double q = double.tryParse(val) ?? 1.0;
    if (q <= 0) q = 1.0;
    setState(() => _qtyCtrl.text = NumberFormat('#,###.##').format(q));
  }

  Widget _buildShortcutBar() {
    final shortcuts = [
      {'key': 'F1', 'label': 'จำนวน'},
      {'key': 'F2', 'label': 'ลูกค้า'},
      {'key': 'F3', 'label': 'ค้นหา'},
      {'key': 'F4', 'label': 'สินค้าด่วน'},
      {'key': 'F5', 'label': 'ยกเลิกบิล'},
      {'key': 'F9', 'label': 'คิดเงิน'},
    ];

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: shortcuts.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s['key']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 4),
                Text(s['label']!,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final posState = Provider.of<PosStateManager>(context, listen: false);
    final key = event.logicalKey;

    // ✅ Safe Manual Capture: Only intercept specific keys
    if (key == LogicalKeyboardKey.f1) {
      _showQuantityDialog();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      _showCustomerDialog(posState);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f3) {
      _showSearchDialog(posState);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f4) {
      _showQuickMenuDialog(posState);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      _resetTransaction();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f9) {
      _openPaymentModal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_barcodeCtrl.text.isNotEmpty) {
        setState(() => _barcodeCtrl.clear());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      // ✅ Only handle Enter if Barcode Field is focused
      if (_barcodeFocusNode.hasFocus) {
        if (_barcodeCtrl.text.trim().isNotEmpty) {
          _handleBarcodeSubmit(_barcodeCtrl.text, posState);
        } else {
          _openPaymentModal();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // ⚠️ Allow other keys (letters, numbers) to propagate to TextField
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final posState = Provider.of<PosStateManager>(context);
    return CallbackShortcuts(
      bindings: {
        // F1: Quantity (Requested by User)
        const SingleActivator(LogicalKeyboardKey.f1): () =>
            _showQuantityDialog(),
        // F2: Customer
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _showCustomerDialog(posState),
        // F3: Search
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _showSearchDialog(posState),
        // F4: Quick Menu
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            _showQuickMenuDialog(posState),
        // F5: Reset
        const SingleActivator(LogicalKeyboardKey.f5): () => _resetTransaction(),
        // F9: Payment (Moved from F1)
        const SingleActivator(LogicalKeyboardKey.f9): () => _openPaymentModal(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_barcodeCtrl.text.isNotEmpty) {
            setState(() => _barcodeCtrl.clear());
          }
          // User requested to remove ESC clearing the cart
          // else {
          //   _resetTransaction();
          // }
        },
      },
      child: Stack(
        children: [
          Focus(
            focusNode: _keyboardListenerFocus,
            autofocus:
                false, // ❌ Disable autofocus on guard to prevent stealing from TextField
            onKeyEvent: _handleKeyEvent, // ✅ Intercept Keys
            child: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (MediaQuery.of(context).viewInsets.bottom == 0) {
                    _barcodeFocusNode.requestFocus();
                  }
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 900;

                    if (isWide) {
                      // Desktop / Wide Layout
                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                PosControlBar(
                                  barcodeCtrl: _barcodeCtrl,
                                  qtyCtrl: _qtyCtrl,
                                  barcodeFocusNode: _barcodeFocusNode,
                                  onScan: (val) {
                                    if (val.isEmpty) {
                                      _openPaymentModal();
                                    } else {
                                      _handleBarcodeSubmit(val, posState);
                                    }
                                  },
                                  onSearch: () => _showSearchDialog(posState),
                                  onQtyTap: _showQuantityDialog,
                                ),
                                Expanded(
                                  child: PosCartList(
                                    items: posState.cart,
                                    onEdit: (index) =>
                                        _showEditItemDialog(posState, index),
                                    onDelete: (index) async {
                                      if (!_checkPermission(
                                          'void_item', 'ลบรายการสินค้า')) {
                                        return;
                                      }
                                      await posState.removeItem(index);
                                    },
                                    onUpdateQuantity: (index, newQty) async {
                                      try {
                                        await posState.updateItemQuantity(
                                            index, newQty);
                                      } catch (e) {
                                        if (context.mounted) {
                                          AlertService.show(
                                            context: context,
                                            message: e
                                                .toString()
                                                .replaceAll('Exception: ', ''),
                                            type: 'error',
                                            duration:
                                                const Duration(seconds: 3),
                                          );
                                          setState(() {});
                                        }
                                      }
                                    },
                                    onUpdatePrice: (index, newPrice) async {
                                      if (!posState.allowPriceEdit) {
                                        if (!_checkPermission(
                                            'price_edit', 'แก้ไขราคา')) {
                                          setState(() {});
                                          return;
                                        }
                                      }
                                      await posState.updateItemPrice(
                                          index, newPrice);
                                    },
                                  ),
                                ),
                                _buildShortcutBar(), // ✅ Footer Bar Desktop
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 1,
                            child: PosPaymentPanel(
                              onPaymentSuccess: _resetTransaction,
                              onClear: _resetTransaction,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Tablet / Narrow Layout
                      return Column(
                        children: [
                          PosControlBar(
                            barcodeCtrl: _barcodeCtrl,
                            qtyCtrl: _qtyCtrl,
                            barcodeFocusNode: _barcodeFocusNode,
                            onScan: (val) {
                              if (val.isEmpty) {
                                _openPaymentModal();
                              } else {
                                _handleBarcodeSubmit(val, posState);
                              }
                            },
                            onSearch: () => _showSearchDialog(posState),
                            onQtyTap: _showQuantityDialog,
                          ),
                          Expanded(
                            child: PosCartList(
                              items: posState.cart,
                              onEdit: (index) =>
                                  _showEditItemDialog(posState, index),
                              onDelete: (index) async {
                                if (!_checkPermission(
                                    'void_item', 'ลบรายการสินค้า')) {
                                  return;
                                }
                                await posState.removeItem(index);
                              },
                              onUpdateQuantity: (index, newQty) async {
                                try {
                                  await posState.updateItemQuantity(
                                      index, newQty);
                                } catch (e) {
                                  if (context.mounted) {
                                    AlertService.show(
                                      context: context,
                                      message: e
                                          .toString()
                                          .replaceAll('Exception: ', ''),
                                      type: 'error',
                                      duration: const Duration(seconds: 3),
                                    );
                                    setState(() {});
                                  }
                                }
                              },
                              onUpdatePrice: (index, newPrice) async {
                                if (!posState.allowPriceEdit) {
                                  if (!_checkPermission(
                                      'price_edit', 'แก้ไขราคา')) {
                                    setState(() {});
                                    return;
                                  }
                                }
                                await posState.updateItemPrice(index, newPrice);
                              },
                            ),
                          ),
                          _buildShortcutBar(), // ✅ Footer Bar Tablet
                          const Divider(height: 1),
                          // Payment Panel needs to be smaller vertical or full height?
                          // Let's give it fixed height or Flexible.
                          // If we use Expanded, it might squish cart too much if list is long.
                          // Let's use SizedBox for height approx 40%
                          SizedBox(
                            height: constraints.maxHeight * 0.45,
                            child: PosPaymentPanel(
                              onPaymentSuccess: _resetTransaction,
                              onClear: _resetTransaction,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('กำลังบันทึก...',
                        style: TextStyle(color: Colors.white, fontSize: 18))
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Front Store Checklist Dialog
  void _showFrontStoreChecklist(List<OrderItem> items) {
    showDialog(
        context: context,
        barrierDismissible: true, // Allow clicking outside to close
        builder: (ctx) {
          // Simple state for checkboxes
          final List<bool> checked = List.filled(items.length, false);
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.store, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('รายการจัดของหน้าร้าน (Front Store List)'),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  height: 400,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.blue[50],
                        child: const Text(
                            'กรุณาจัดเตรียมสินค้าเหล่านี้ให้ลูกค้า (ไม่รวมของหลังร้าน)'),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (ctx, i) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            return CheckboxListTile(
                              value: checked[i],
                              onChanged: (val) {
                                setState(() => checked[i] = val ?? false);
                              },
                              title: Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'จำนวน: ${NumberFormat('#,##0.##').format(item.quantity)} หน่วย'),
                              secondary: item.product?.shelfLocation != null &&
                                      item.product!.shelfLocation!.isNotEmpty
                                  ? Chip(
                                      label: Text(
                                          'shelf: ${item.product!.shelfLocation}'),
                                      backgroundColor: Colors.yellow[100],
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  CustomButton(
                    label: 'พิมพ์ใบจัดของ (Print)',
                    icon: Icons.print,
                    onPressed: () {
                      Navigator.pop(ctx);
                      ReceiptService().printPickingList(items);
                      AlertService.show(
                          context: context,
                          message: 'ส่งพิมพ์ใบจัดของเรียบร้อย',
                          type: 'success');
                    },
                  ),
                  CustomButton(
                    label: 'ปิด (Close)',
                    type: ButtonType.secondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              );
            },
          );
        });
  }
}
