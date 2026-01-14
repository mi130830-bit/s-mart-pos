import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../models/product.dart';
import '../../models/customer.dart';
import '../../repositories/product_repository.dart';
import '../../state/auth_provider.dart';

import '../products/product_list_view.dart';
import '../products/widgets/product_search_dialog_for_select.dart';
import '../products/widgets/quick_menu_dialog.dart';
// import '../../services/sales/cart_service.dart';
// import '../../services/sales/held_bill_manager.dart';
// import '../../services/sales/order_processing_service.dart';
import '../../services/alert_service.dart';
import 'payment_modal.dart';
import 'pos_state_manager.dart';
import 'pos_control_bar.dart';
import 'pos_cart_list.dart';
import 'pos_payment_panel.dart';
import '../../utils/barcode_utils.dart';
// import '../../services/alert_service.dart';
import '../customers/customer_search_dialog.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

class PosCheckoutScreen extends StatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  final FocusNode _barcodeFocusNode = FocusNode();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  final ProductRepository _productRepo = ProductRepository();
  // ❌ REMOVED: _productsFuture (No loading all products)

  bool _canEditPrice = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // ❌ REMOVED: getAllProducts() call
    _loadSettings();
    _barcodeCtrl.addListener(_onBarcodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _canEditPrice = prefs.getBool('allow_pos_price_edit') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeCtrl.removeListener(_onBarcodeChanged);
    _barcodeFocusNode.dispose();
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

      bool isCredit =
          posState.lastPaymentMethod.toLowerCase().contains('credit') ||
              posState.lastPaymentMethod.contains('เงินเชื่อ');

      await posState.clearCart(returnStock: false);
      posState.selectCustomer(null);

      if (mounted) {
        AlertService.show(
          context: context,
          message: isCredit ? '📝 บันทึกลงบัญชีสำเร็จ' : '💵 ชำระเงินสำเร็จ',
          type: isCredit ? 'warning' : 'success',
          duration: const Duration(seconds: 2),
        );
      }
    } else {
      _barcodeFocusNode.requestFocus();
    }
  }

  void _onBarcodeChanged() {
    final text = _barcodeCtrl.text;
    if (text.isEmpty) return;

    final normalized = BarcodeUtils.fixThaiInput(text);
    if (normalized != text) {
      _barcodeCtrl.text = normalized;
      _barcodeCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _barcodeCtrl.text.length));
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (normalized.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final currentText = _barcodeCtrl.text;
        if (currentText.isNotEmpty) {
          final posState = Provider.of<PosStateManager>(context, listen: false);
          _handleBarcodeSubmit(currentText, posState);
        }
      });
    }
  }

  // ✅ New Logic: Search via State Manager
  void _handleBarcodeSubmit(String value, PosStateManager posState) async {
    if (value.isEmpty) {
      _barcodeFocusNode.requestFocus();
      return;
    }

    // Debounce double submission if key is held? (Not strictly needed if async awaited properly, but good practice)

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

    _barcodeFocusNode.requestFocus();
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
      double? overrideConversionFactor}) async {
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
      if (mounted) {
        AlertService.show(
            context: context, message: e.toString(), type: 'error');
      }
    }
    _barcodeFocusNode.requestFocus();
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
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 30),
          const SizedBox(width: 10),
          Expanded(
              child: Text('ไม่พบสินค้า: $barcode',
                  style: const TextStyle(fontSize: 18))),
        ]),
        content: const Text('คุณต้องการทำรายการอย่างไร?',
            style: TextStyle(fontSize: 16)),
        actions: [
          CustomButton(
            icon: Icons.add_circle,
            label: 'ลงทะเบียนสินค้าใหม่',
            backgroundColor: Colors.purple,
            onPressed: () {
              if (!_checkPermission('manage_product', 'ลงทะเบียนสินค้าใหม่')) {
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
    );
  }

  void _openCreateProductDialog(
      String barcode, PosStateManager posState, double qty) async {
    final tempProduct = Product(
        id: 0,
        name: '',
        barcode: barcode,
        retailPrice: 0,
        costPrice: 0,
        productType: 0,
        trackStock: true,
        stockQuantity: 0,
        points: 0);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          ProductFormDialog(repo: _productRepo, product: tempProduct),
    );

    if (result == true) {
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
          await _addToCartWithFeedback(product, quantity, posState);
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

  // _showEditItemDialog (Same as original)
  void _showEditItemDialog(PosStateManager posState, int index) {
    final item = posState.cart[index];
    final qtyCtrl = TextEditingController(
        text: item.quantity.toDouble() % 1 == 0
            ? item.quantity.toStringAsFixed(0)
            : item.quantity.toString());
    final priceCtrl = TextEditingController(text: item.price.toString());
    final discountCtrl = TextEditingController(text: '0');
    final commentCtrl = TextEditingController(text: item.comment);
    int discountMode = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, st) {
          Future<void> saveAction() async {
            final newQty =
                double.tryParse(qtyCtrl.text) ?? item.quantity.toDouble();
            if (newQty != item.quantity.toDouble()) {
              await posState.updateItemQuantity(index, newQty);
            }

            if (_canEditPrice) {
              final newPrice =
                  double.tryParse(priceCtrl.text) ?? item.price.toDouble();
              if (newPrice != item.price.toDouble()) {
                posState.updateItemPrice(index, newPrice);
              }
            }

            double inputVal = double.tryParse(discountCtrl.text) ?? 0;
            if (inputVal >= 0) {
              if (!_checkPermission('pos_discount', 'ให้ส่วนลด')) return;

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
              posState.updateItemDiscount(index, finalDiscount,
                  isPercent: false);
            }

            if (commentCtrl.text != item.comment) {
              posState.updateItemComment(index, commentCtrl.text);
            }

            if (ctx.mounted) Navigator.pop(ctx);
          }

          return AlertDialog(
            title: Text('แก้ไข: ${item.productName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('จำนวนสินค้า:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 5),
                  CustomTextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('ชิ้น/หน่วย'),
                    ),
                    autofocus: true,
                    selectAllOnFocus: true, // ✅ Auto-select
                    onTap: () => qtyCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: qtyCtrl.text.length),
                    onSubmitted: (_) => saveAction(),
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                  if (_canEditPrice) ...[
                    const SizedBox(height: 10),
                    const Text('ราคาต่อหน่วย:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    CustomTextField(
                      controller: priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefixText: '฿ ',
                      selectAllOnFocus: true, // ✅ Auto-select
                      onSubmitted: (_) => saveAction(),
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                  ],
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

  @override
  Widget build(BuildContext context) {
    final posState = Provider.of<PosStateManager>(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): () => _openPaymentModal(),
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _showCustomerDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _showSearchDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            _showQuickMenuDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f5): () => _resetTransaction(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_barcodeCtrl.text.isNotEmpty) {
            setState(() => _barcodeCtrl.clear());
          }
          // User requested to remove ESC clearing the cart
          // else {
          //   _resetTransaction();
          // }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_barcodeCtrl.text.trim().isNotEmpty) {
            _handleBarcodeSubmit(_barcodeCtrl.text, posState);
          } else {
            _openPaymentModal();
          }
        },
      },
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
                            onScan: (val) =>
                                _handleBarcodeSubmit(val, posState),
                            onSearch: () => _showSearchDialog(posState),
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
                                await posState.updateItemQuantity(
                                    index, newQty);
                              },
                            ),
                          ),
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
                      onScan: (val) => _handleBarcodeSubmit(val, posState),
                      onSearch: () => _showSearchDialog(posState),
                    ),
                    Expanded(
                      child: PosCartList(
                        items: posState.cart,
                        onEdit: (index) => _showEditItemDialog(posState, index),
                        onDelete: (index) async {
                          if (!_checkPermission(
                              'void_item', 'ลบรายการสินค้า')) {
                            return;
                          }
                          await posState.removeItem(index);
                        },
                        onUpdateQuantity: (index, newQty) async {
                          await posState.updateItemQuantity(index, newQty);
                        },
                      ),
                    ),
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
    );
  }
}
