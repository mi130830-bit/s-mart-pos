import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../models/product.dart';
import '../../models/customer.dart';
import '../../repositories/product_repository.dart';
import '../../state/auth_provider.dart';
import '../products/dialogs/product_form/product_form_dialog.dart';
import '../products/widgets/product_search_dialog_for_select.dart';
import '../products/widgets/quick_menu_dialog.dart';
import '../../models/order_item.dart';
import '../../services/alert_service.dart';
import 'payment_modal.dart';
import 'pos_state_manager.dart';
import 'pos_control_bar.dart';
import 'pos_cart_list.dart';
import 'pos_payment_panel.dart';
import '../../utils/barcode_utils.dart';
import '../customers/customer_search_dialog.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../utils/pos_reprint_barcode_router.dart';

// Extracted widgets & dialogs
import 'widgets/pos_shortcut_bar.dart';
import 'dialogs/pos_quantity_dialog.dart';
import 'dialogs/pos_weighing_dialog.dart';
import 'dialogs/pos_quick_sale_dialog.dart';
import 'dialogs/pos_multiple_matches_dialog.dart';
import 'dialogs/pos_stock_insufficient_dialog.dart';
import 'dialogs/pos_not_found_dialog.dart';
import 'dialogs/pos_edit_item_dialog.dart';
import 'dialogs/pos_front_store_checklist_dialog.dart';
import 'layouts/pos_desktop_layout.dart';
import 'layouts/pos_tablet_layout.dart';

class PosCheckoutScreen extends StatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocus = FocusNode();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final ProductRepository _productRepo = ProductRepository();

  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _isProcessing = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _barcodeCtrl.addListener(_onBarcodeChanged);
    PosReprintBarcodeRouter.instance.addListener(_onReprintDialogBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    PosReprintBarcodeRouter.instance.removeListener(_onReprintDialogBarcode);
    _debounceTimer?.cancel();
    _barcodeCtrl.removeListener(_onBarcodeChanged);
    _barcodeFocusNode.dispose();
    _keyboardListenerFocus.dispose();
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  // ── Barcode Router (Reprint Pass-through) ────────────────────────────────────

  void _onReprintDialogBarcode() {
    final barcode = PosReprintBarcodeRouter.instance.value;
    if (barcode == null || barcode.isEmpty) return;
    PosReprintBarcodeRouter.consume();
    if (!mounted) return;
    final posState = Provider.of<PosStateManager>(context, listen: false);
    _handleBarcodeSubmit(barcode, posState);
  }

  // ── Permission Helper ─────────────────────────────────────────────────────────

  bool _checkPermission(String key, String actionName) {
    if (!mounted) return false;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.hasPermission(key)) return true;
    ConfirmDialog.show(context,
        title: 'ไม่มีสิทธิ์เข้าถึง',
        content: 'คุณไม่มีสิทธิ์: $actionName',
        confirmText: 'ตกลง',
        isDestructive: false);
    return false;
  }

  // ── Cart Actions ──────────────────────────────────────────────────────────────

  void _resetTransaction() async {
    if (!_checkPermission('void_bill', 'ยกเลิกบิล (Clear Bill)')) return;
    final posState = Provider.of<PosStateManager>(context, listen: false);
    if (posState.cart.isEmpty) {
      posState.selectCustomer(null);
      _qtyCtrl.text = '1';
      _barcodeFocusNode.requestFocus();
      return;
    }
    final confirm = await ConfirmDialog.show(context,
        title: 'ยืนยันล้างรายการ',
        content:
            'ต้องการยกเลิกและเริ่มรายการใหม่ใช่ไหม? (${posState.cart.length} รายการจะถูกลบออก)',
        confirmText: 'ล้างรายการ',
        cancelText: 'ยกเลิก',
        isDestructive: true);
    if (confirm != true || !mounted) return;
    await posState.clearCart(returnStock: true);
    posState.selectCustomer(null);
    _qtyCtrl.text = '1';
    _barcodeFocusNode.requestFocus();
    if (mounted) {
      AlertService.show(
          context: context,
          message: 'เริ่มรายการใหม่เรียบร้อย',
          type: 'warning');
    }
  }

  void _showCustomerDialog(PosStateManager posState) async {
    final customer = await showDialog<Customer>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CustomerSearchDialog());
    if (customer != null) posState.selectCustomer(customer);
    _barcodeFocusNode.requestFocus();
  }

  void _openPaymentModal() async {
    final posState = Provider.of<PosStateManager>(context, listen: false);
    if (posState.cart.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentModal(onPaymentSuccess: () {}),
    );

    if (result == true) {
      if (!mounted) return;
      final posState = Provider.of<PosStateManager>(context, listen: false);
      final cartSnapshot = List<OrderItem>.from(posState.cart);
      final isCredit =
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
        final frontItems = cartSnapshot
            .where((i) => !(i.product?.isWarehouseItem ?? false))
            .toList();
        if (frontItems.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              PosFrontStoreChecklistDialog.show(context, items: frontItems);
            }
          });
        }
      }
    } else {
      _barcodeFocusNode.requestFocus();
    }
  }

  // ── Barcode Handling ──────────────────────────────────────────────────────────

  void _onBarcodeChanged() {
    final text = _barcodeCtrl.text;
    if (text.isEmpty) return;
    final normalized = BarcodeUtils.fixThaiInput(text);
    if (normalized != text) {
      _barcodeCtrl.text = normalized;
      _barcodeCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: normalized.length));
    }
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (normalized.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final current = _barcodeCtrl.text;
        if (current.isNotEmpty && !_isProcessing) {
          final posState =
              Provider.of<PosStateManager>(context, listen: false);
          _handleBarcodeSubmit(current, posState);
        }
      });
    }
  }

  void _handleBarcodeSubmit(String value, PosStateManager posState) async {
    _debounceTimer?.cancel();
    if (value.isEmpty) { _barcodeFocusNode.requestFocus(); return; }
    if (_isProcessing) return;
    _isProcessing = true;
    setState(() => _isLoading = true);

    try {
      double quantity = double.tryParse(_qtyCtrl.text) ?? 1.0;
      if (quantity <= 0) quantity = 1.0;

      final result = await posState.handleBarcode(value, quantity: quantity);
      if (!mounted) return;

      switch (result.status) {
        case ScanStatus.success:
          _barcodeCtrl.clear();
          setState(() => _qtyCtrl.text = '1');
          if (result.product != null) {
            AlertService.show(
              context: context,
              message:
                  'เพิ่ม ${result.product!.name} x${NumberFormat('#,##0').format(quantity)} แล้ว',
              type: 'success',
              duration: const Duration(seconds: 1),
            );
            if (result.product!.trackStock &&
                result.product!.stockQuantity <=
                    (result.product!.reorderPoint ?? 0)) {
              PosNotFoundDialog.showLowStockAlert(context,
                  product: result.product!);
            }
          }

        case ScanStatus.multipleMatches:
          if (result.matches != null && result.matches!.isNotEmpty) {
            await PosMultipleMatchesDialog.show(context,
                matches: result.matches!,
                quantity: quantity,
                onSelected: (p, qty) =>
                    _addToCartWithFeedback(p, qty, posState));
          }

        case ScanStatus.notFound:
          _barcodeCtrl.clear();
          await PosNotFoundDialog.show(context,
              barcode: value,
              posState: posState,
              qty: quantity,
              onCreateProduct: (b, ps, q) =>
                  _openCreateProductDialog(b, ps, q),
              onQuickSale: (b, ps, q) =>
                  PosQuickSaleDialog.show(context,
                      barcode: b,
                      posState: ps,
                      qty: q,
                      onComplete: () {
                        _qtyCtrl.text = '1';
                        _barcodeFocusNode.requestFocus();
                      }),
              onBarcodeScanned: (b, ps) => _handleBarcodeSubmit(b, ps),
              checkPermission: _checkPermission);

        case ScanStatus.error:
          AlertService.show(
              context: context,
              message: result.message ?? 'Error scanning',
              type: 'error');

        case ScanStatus.requiresWeight:
          if (result.product != null) {
            await PosWeighingDialog.show(context,
                product: result.product!,
                onConfirm: (p, w) =>
                    _addToCartWithFeedback(p, w, posState));
          }
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted && msg.contains('สต๊อกสินค้า')) {
        AlertService.show(context: context, message: msg, type: 'warning');
      } else {
        debugPrint('Scan Error: $e');
        if (mounted) {
          AlertService.show(
              context: context, message: 'Scan Error: $e', type: 'error');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _isProcessing = false;
      _barcodeFocusNode.requestFocus();
    }
  }

  // ── Cart Helpers ──────────────────────────────────────────────────────────────

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
        await PosStockInsufficientDialog.show(context,
            errorMsg: msg,
            product: product,
            posState: posState,
            overridePrice: overridePrice,
            overrideUnit: overrideUnit,
            overrideConversionFactor: overrideConversionFactor,
            onComplete: () {
              _barcodeCtrl.clear();
              setState(() => _qtyCtrl.text = '1');
            });
      } else if (mounted) {
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
    if (refocus) _barcodeFocusNode.requestFocus();
  }

  Future<void> _openCreateProductDialog(
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

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          ProductFormDialog(repo: _productRepo, product: tempProduct),
    );

    if (result != null) {
      final matches = await _productRepo.getProductsPaginated(1, 1,
          searchTerm: barcode);
      if (matches.isNotEmpty) {
        final newProduct = matches.first;
        await posState.addProductToCart(newProduct, quantity: qty);
        if (mounted) {
          AlertService.show(
              context: context,
              message: 'ลงทะเบียนและเพิ่ม "${newProduct.name}" แล้ว',
              type: 'success');
        }
        _qtyCtrl.text = '1';
      }
    }
    _barcodeFocusNode.requestFocus();
  }

  void _showSearchDialog(PosStateManager posState) async {
    final selected = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductSearchDialogForSelect(repo: _productRepo),
    );
    if (selected != null) {
      final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
      await _addToCartWithFeedback(selected, qty, posState);
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
          final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
          await _addToCartWithFeedback(product, qty, posState,
              refocus: false);
        },
      ),
    );
  }

  void _applyQuantity(String val) {
    double q = double.tryParse(val) ?? 1.0;
    if (q <= 0) q = 1.0;
    setState(() => _qtyCtrl.text =
        q == q.truncateToDouble() ? q.toInt().toString() : q.toString());
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final posState = Provider.of<PosStateManager>(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): () =>
            PosQuantityDialog.show(context, onConfirm: _applyQuantity),
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _showCustomerDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _showSearchDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            _showQuickMenuDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            _resetTransaction(),
        const SingleActivator(LogicalKeyboardKey.f9): () =>
            _openPaymentModal(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_barcodeCtrl.text.isNotEmpty) {
            setState(() => _barcodeCtrl.clear());
          }
        },
      },
      child: Stack(
        children: [
          Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (MediaQuery.of(context).viewInsets.bottom == 0) {
                  _barcodeFocusNode.requestFocus();
                }
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;

                  final controlBar = PosControlBar(
                    barcodeCtrl: _barcodeCtrl,
                    qtyCtrl: _qtyCtrl,
                    barcodeFocusNode: _barcodeFocusNode,
                    onScan: (val) => val.isEmpty
                        ? _openPaymentModal()
                        : _handleBarcodeSubmit(val, posState),
                    onSearch: () => _showSearchDialog(posState),
                    onQtyTap: () => PosQuantityDialog.show(context,
                        onConfirm: _applyQuantity),
                  );
                  final cartList = _buildCartList(posState);
                  const shortcutBar = PosShortcutBar();
                  final paymentPanel = PosPaymentPanel(
                    onPaymentSuccess: _resetTransaction,
                    onClear: _resetTransaction,
                  );

                  if (isWide) {
                    return PosDesktopLayout(
                      controlBar: controlBar,
                      cartList: cartList,
                      shortcutBar: shortcutBar,
                      paymentPanel: paymentPanel,
                    );
                  } else {
                    return PosTabletLayout(
                      controlBar: controlBar,
                      cartList: cartList,
                      shortcutBar: shortcutBar,
                      paymentPanel: paymentPanel,
                      maxHeight: constraints.maxHeight,
                    );
                  }
                },
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
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartList(PosStateManager posState) {
    return PosCartList(
      items: posState.cart,
      onEdit: (index) => PosEditItemDialog.show(context,
          posState: posState,
          index: index,
          checkPermission: _checkPermission)
          .then((_) => _barcodeFocusNode.requestFocus()),
      onDelete: (index) async {
        if (!_checkPermission('void_item', 'ลบรายการสินค้า')) return;
        await posState.removeItem(index);
        _barcodeFocusNode.requestFocus();
      },
      onUpdateQuantity: (index, newQty) async {
        try {
          await posState.updateItemQuantity(index, newQty);
          _barcodeFocusNode.requestFocus();
        } catch (e) {
          if (mounted) {
            AlertService.show(
              context: context,
              message: e.toString().replaceAll('Exception: ', ''),
              type: 'error',
              duration: const Duration(seconds: 3),
            );
            setState(() {});
          }
          _barcodeFocusNode.requestFocus();
        }
      },
      onUpdatePrice: (index, newPrice) async {
        if (!posState.allowPriceEdit) {
          if (!_checkPermission('price_edit', 'แก้ไขราคา')) {
            setState(() {});
            _barcodeFocusNode.requestFocus();
            return;
          }
        }
        await posState.updateItemPrice(index, newPrice);
        _barcodeFocusNode.requestFocus();
      },
      onUpdateDiscount: (index, newDiscount) {
        posState.updateItemDiscount(index, newDiscount.toDouble());
        _barcodeFocusNode.requestFocus();
      },
    );
  }
}
