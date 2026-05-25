import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/alert_service.dart';
import 'pos_state_manager.dart';
import 'pos_control_bar.dart';
import 'pos_cart_list.dart';
import 'pos_payment_panel.dart';

// Extracted widgets & dialogs
import 'widgets/pos_shortcut_bar.dart';
import 'widgets/pos_layout_selector.dart';
import 'dialogs/pos_quantity_dialog.dart';
import 'dialogs/pos_edit_item_dialog.dart';
import 'mixins/pos_barcode_handler_mixin.dart';

class PosCheckoutScreen extends ConsumerStatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  ConsumerState<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends ConsumerState<PosCheckoutScreen> with PosBarcodeHandlerMixin {
  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    initBarcodeHandler();
  }

  @override
  void dispose() {
    disposeBarcodeHandler();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(posProvider);
    final posState = ref.watch(posProvider.notifier);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): () =>
            PosQuantityDialog.show(context, onConfirm: applyQuantity),
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            showCustomerDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            showSearchDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            showQuickMenuDialog(posState),
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            resetTransaction(),
        const SingleActivator(LogicalKeyboardKey.f9): () =>
            openPaymentModal(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (barcodeCtrl.text.isNotEmpty) {
            setState(() => barcodeCtrl.clear());
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
                  barcodeFocusNode.requestFocus();
                }
              },
              child: PosLayoutSelector(
                controlBar: PosControlBar(
                  barcodeCtrl: barcodeCtrl,
                  qtyCtrl: qtyCtrl,
                  barcodeFocusNode: barcodeFocusNode,
                  onScan: (val) => val.isEmpty
                      ? openPaymentModal()
                      : handleBarcodeSubmit(val, posState),
                  onSearch: () => showSearchDialog(posState),
                  onQtyTap: () => PosQuantityDialog.show(context,
                      onConfirm: applyQuantity),
                ),
                cartList: _buildCartList(posState),
                shortcutBar: const PosShortcutBar(),
                paymentPanel: PosPaymentPanel(
                  onPaymentSuccess: resetTransaction,
                  onClear: resetTransaction,
                  onHoldSuccess: () {
                    posState.selectCustomer(null);
                    setState(() => qtyCtrl.text = '1');
                    barcodeFocusNode.requestFocus();
                  },
                ),
              ),
            ),
          ),
          if (isLoading)
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

  Widget _buildCartList(PosStateNotifier posState) {
    final editId = ref.watch(posProvider).editingOrderId;
    return Column(
      children: [
        // ✅ [NEW] Banner แจ้งเตือนโหมดแก้ไขบิล
        if (editId != null)
          Material(
            color: Colors.orange.shade700,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ กำลังแก้ไขบิลค้างชำระ #$editId — เพิ่ม/ลดรายการแล้วกดชำระเงินเพื่อบันทึก',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    label: const Text('ยกเลิกการแก้ไข',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () => posState.cancelOrderEditing(),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: PosCartList(
      items: posState.cart,
      onEdit: (index) => PosEditItemDialog.show(context,
          posState: posState,
          index: index,
          checkPermission: checkPermission)
          .then((_) => barcodeFocusNode.requestFocus()),
      onDelete: (index) async {
        if (!checkPermission('void_item', 'ลบรายการสินค้า')) return;
        await posState.removeItem(index);
        barcodeFocusNode.requestFocus();
      },
      onUpdateQuantity: (index, newQty) async {
        try {
          await posState.updateItemQuantity(index, newQty);
          barcodeFocusNode.requestFocus();
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
          barcodeFocusNode.requestFocus();
        }
      },
      onUpdatePrice: (index, newPrice) async {
        if (!posState.allowPriceEdit) {
          if (!checkPermission('price_edit', 'แก้ไขราคา')) {
            setState(() {});
            barcodeFocusNode.requestFocus();
            return;
          }
        }
        await posState.updateItemPrice(index, newPrice);
        barcodeFocusNode.requestFocus();
      },
      onUpdateDiscount: (index, newDiscount) {
        posState.updateItemDiscount(index, newDiscount.toDouble());
        barcodeFocusNode.requestFocus();
      },
    ),
        ), // close Expanded
      ],    // close Column children
    );     // close Column
  }
}
