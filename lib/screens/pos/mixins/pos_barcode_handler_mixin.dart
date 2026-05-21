import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/intl.dart';

import '../../../models/product.dart';
import '../../../models/customer.dart';
import '../../../repositories/product_repository.dart';
import '../../../state/auth_provider.dart';
import '../../../services/alert_service.dart';
import '../../../services/logger_service.dart';
import '../../../utils/barcode_utils.dart';
import '../../../utils/pos_reprint_barcode_router.dart';
import '../../../widgets/common/confirm_dialog.dart';
import '../pos_state_manager.dart';

import '../payment_modal.dart';
import '../dialogs/pos_weighing_dialog.dart';
import '../dialogs/pos_quick_sale_dialog.dart';
import '../dialogs/pos_multiple_matches_dialog.dart';
import '../dialogs/pos_stock_insufficient_dialog.dart';
import '../dialogs/pos_not_found_dialog.dart';
import '../dialogs/pos_front_store_checklist_dialog.dart';
import '../../products/dialogs/product_form/product_form_dialog.dart';
import '../../products/widgets/product_search_dialog_for_select.dart';
import '../../products/widgets/quick_menu_dialog.dart';
import '../../../models/order_item.dart';
import '../../customers/customer_search_dialog.dart';

mixin PosBarcodeHandlerMixin<T extends StatefulWidget> on State<T> {
  final FocusNode barcodeFocusNode = FocusNode();
  final FocusNode keyboardListenerFocus = FocusNode();
  final TextEditingController barcodeCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final ProductRepository productRepo = ProductRepository();

  Timer? debounceTimer;
  bool isLoading = false;
  bool isProcessing = false;

  void initBarcodeHandler() {
    barcodeCtrl.addListener(onBarcodeChanged);
    PosReprintBarcodeRouter.instance.addListener(onReprintDialogBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      barcodeFocusNode.requestFocus();
    });
  }

  void disposeBarcodeHandler() {
    PosReprintBarcodeRouter.instance.removeListener(onReprintDialogBarcode);
    debounceTimer?.cancel();
    barcodeCtrl.removeListener(onBarcodeChanged);
    barcodeFocusNode.dispose();
    keyboardListenerFocus.dispose();
    barcodeCtrl.dispose();
    qtyCtrl.dispose();
  }

  void onReprintDialogBarcode() {
    final barcode = PosReprintBarcodeRouter.instance.value;
    if (barcode == null || barcode.isEmpty) return;
    PosReprintBarcodeRouter.consume();
    if (!mounted) return;
    final posState = ProviderScope.containerOf(context).read(posProvider.notifier);
    handleBarcodeSubmit(barcode, posState);
  }

  bool checkPermission(String key, String actionName) {
    if (!mounted) return false;
    final auth = ProviderScope.containerOf(context, listen: false).read(authProvider);
    if (auth.hasPermission(key)) return true;
    ConfirmDialog.show(context,
        title: 'ไม่มีสิทธิ์เข้าถึง',
        content: 'คุณไม่มีสิทธิ์: $actionName',
        confirmText: 'ตกลง',
        isDestructive: false);
    return false;
  }

  void resetTransaction() async {
    if (!checkPermission('void_bill', 'ยกเลิกบิล (Clear Bill)')) return;
    final posState = ProviderScope.containerOf(context).read(posProvider.notifier);
    if (posState.cart.isEmpty) {
      posState.selectCustomer(null);
      setState(() => qtyCtrl.text = '1');
      barcodeFocusNode.requestFocus();
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
    setState(() => qtyCtrl.text = '1');
    barcodeFocusNode.requestFocus();
    if (mounted) {
      AlertService.show(
          context: context,
          message: 'เริ่มรายการใหม่เรียบร้อย',
          type: 'warning');
    }
  }

  void showCustomerDialog(PosStateNotifier posState) async {
    final customer = await showDialog<Customer>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CustomerSearchDialog());
    if (customer != null) posState.selectCustomer(customer);
    barcodeFocusNode.requestFocus();
  }

  void openPaymentModal() async {
    final posState = ProviderScope.containerOf(context).read(posProvider.notifier);
    if (posState.cart.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentModal(onPaymentSuccess: () {}),
    );

    if (result == true) {
      if (!mounted) return;
      final posState = ProviderScope.containerOf(context).read(posProvider.notifier);
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
      barcodeFocusNode.requestFocus();
    }
  }

  void onBarcodeChanged() {
    final text = barcodeCtrl.text;
    if (text.isEmpty) return;
    final normalized = BarcodeUtils.fixThaiInput(text);
    if (normalized != text) {
      barcodeCtrl.text = normalized;
      barcodeCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: normalized.length));
    }
    if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
    if (normalized.length >= 3) {
      debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final current = barcodeCtrl.text;
        if (current.isNotEmpty && !isProcessing) {
          final posState =
              ProviderScope.containerOf(context).read(posProvider.notifier);
          handleBarcodeSubmit(current, posState);
        }
      });
    }
  }

  void handleBarcodeSubmit(String value, PosStateNotifier posState) async {
    debounceTimer?.cancel();
    if (value.isEmpty) {
      barcodeFocusNode.requestFocus();
      return;
    }
    if (isProcessing) return;
    isProcessing = true;
    setState(() => isLoading = true);

    try {
      double quantity = double.tryParse(qtyCtrl.text) ?? 1.0;
      if (quantity <= 0) quantity = 1.0;

      final result = await posState.handleBarcode(value, quantity: quantity);
      if (!mounted) return;

      switch (result.status) {
        case ScanStatus.success:
          barcodeCtrl.clear();
          setState(() => qtyCtrl.text = '1');
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
                    addToCartWithFeedback(p, qty, posState));
          }

        case ScanStatus.notFound:
          barcodeCtrl.clear();
          await PosNotFoundDialog.show(context,
              barcode: value,
              posState: posState,
              qty: quantity,
              onCreateProduct: (b, ps, q) =>
                  openCreateProductDialog(b, ps, q),
              onQuickSale: (b, ps, q) =>
                  PosQuickSaleDialog.show(context,
                      barcode: b,
                      posState: ps,
                      qty: q,
                      onComplete: () {
                        setState(() => qtyCtrl.text = '1');
                        barcodeFocusNode.requestFocus();
                      }),
              onBarcodeScanned: (b, ps) => handleBarcodeSubmit(b, ps),
              checkPermission: checkPermission);

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
                    addToCartWithFeedback(p, w, posState));
          }
      }
    } catch (e, stackTrace) {
      final msg = e.toString();
      if (mounted && msg.contains('สต๊อกสินค้า')) {
        AlertService.show(context: context, message: msg, type: 'warning');
      } else {
        LoggerService.error('PosBarcodeHandler', 'Scan Error: $e', e, stackTrace);
        if (mounted) {
          AlertService.show(
              context: context, message: 'Scan Error: $e', type: 'error');
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
      isProcessing = false;
      barcodeFocusNode.requestFocus();
    }
  }

  Future<void> addToCartWithFeedback(
      Product product, double quantity, PosStateNotifier posState,
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
      barcodeCtrl.clear();
      setState(() => qtyCtrl.text = '1');
      if (mounted) {
        AlertService.show(
          context: context,
          message:
              'เพิ่ม ${product.name} x${NumberFormat('#,##0').format(quantity)} แล้ว',
          type: 'success',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e, stackTrace) {
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
              barcodeCtrl.clear();
              setState(() => qtyCtrl.text = '1');
            });
      } else {
        LoggerService.error('PosBarcodeHandler', 'Add to cart error: $e', e, stackTrace);
        if (mounted) {
          AlertService.show(
              context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
        }
      }
    }
    if (refocus) barcodeFocusNode.requestFocus();
  }

  Future<void> openCreateProductDialog(
      String barcode, PosStateNotifier posState, double qty) async {
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
          ProductFormDialog(repo: productRepo, product: tempProduct),
    );

    if (result != null) {
      try {
        final matches = await productRepo.getProductsPaginated(1, 1,
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
          setState(() => qtyCtrl.text = '1');
        }
      } catch (e, stackTrace) {
        LoggerService.error('PosBarcodeHandler', 'Failed to add newly created product to cart', e, stackTrace);
        if (mounted) {
          AlertService.show(
              context: context,
              message: 'เกิดข้อผิดพลาดในการดึงข้อมูลสินค้า: $e',
              type: 'error');
        }
      }
    }
    barcodeFocusNode.requestFocus();
  }

  void showSearchDialog(PosStateNotifier posState) async {
    final selected = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductSearchDialogForSelect(repo: productRepo),
    );
    if (selected != null) {
      final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
      await addToCartWithFeedback(selected, qty, posState);
    }
    barcodeFocusNode.requestFocus();
  }

  void showQuickMenuDialog(PosStateNotifier posState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuickMenuDialog(
        productRepo: productRepo,
        onProductSelected: (product) async {
          final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
          await addToCartWithFeedback(product, qty, posState,
              refocus: false);
        },
      ),
    );
  }

  void applyQuantity(String val) {
    double q = double.tryParse(val) ?? 1.0;
    if (q <= 0) q = 1.0;
    setState(() => qtyCtrl.text =
        q == q.truncateToDouble() ? q.toInt().toString() : q.toString());
  }
}
