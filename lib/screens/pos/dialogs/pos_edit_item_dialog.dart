import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../pos_state_manager.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog แก้ไขรายการสินค้าในตะกร้า (Qty, Price, Discount, Comment)
class PosEditItemDialog {
  static Future<void> show(
    BuildContext context, {
    required PosStateNotifier posState,
    required int index,
    required bool Function(String key, String actionName) checkPermission,
  }) async {
    final item = posState.cart[index];
    final qtyCtrl = TextEditingController(
        text: NumberFormat('#.##').format(item.quantity.toDouble()));
    final priceCtrl = TextEditingController(
        text: NumberFormat('#.##').format(item.price.toDouble()));
    final qtyFocus = FocusNode();
    final priceFocus = FocusNode();
    final discountCtrl = TextEditingController(text: '0');
    final commentCtrl = TextEditingController(text: item.comment);

    final defaultDiscountMode =
        SettingsService().itemDiscountMode == 'per_piece' ? 0 : 1;
    int discountMode = defaultDiscountMode;

    await showDialog(
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
              if (!posState.allowPriceEdit) {
                if (!checkPermission('price_edit', 'แก้ไขราคา')) return;
              }
              await posState.updateItemPrice(index, newPrice);
            }

            // 3. Discount
            final inputVal =
                double.tryParse(discountCtrl.text) ?? 0;
            if (inputVal >= 0) {
              if (inputVal > 0 &&
                  !checkPermission('pos_discount', 'ให้ส่วนลด')) {
                return;
              }

              if (index < posState.cart.length) {
                final currentItem = posState.cart[index];
                double finalDiscount = 0.0;
                if (discountMode == 0) {
                  finalDiscount =
                      inputVal * currentItem.quantity.toDouble();
                } else if (discountMode == 1) {
                  finalDiscount = inputVal;
                } else if (discountMode == 2) {
                  finalDiscount =
                      (currentItem.price.toDouble() *
                              currentItem.quantity.toDouble()) *
                          (inputVal / 100);
                }
                if (finalDiscount > 0 ||
                    currentItem.discount > Decimal.zero) {
                  posState.updateItemDiscount(index, finalDiscount,
                      isPercent: false);
                }
              }
            }

            // 4. Comment
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
                  CustomTextField(
                    controller: qtyCtrl,
                    focusNode: qtyFocus,
                    label: 'จำนวน (Qty)',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    selectAllOnFocus: true,
                    onTap: () => qtyCtrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: qtyCtrl.text.length),
                    onSubmitted: (_) => priceFocus.requestFocus(),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: priceCtrl,
                    focusNode: priceFocus,
                    label: 'ราคาต่อหน่วย (Price)',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    selectAllOnFocus: true,
                    onTap: () => priceCtrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: priceCtrl.text.length),
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
                        discountMode == 2,
                      ],
                      onPressed: (i) => st(() => discountMode = i),
                      children: const [
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ต่อชิ้น')),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('รวม')),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('%')),
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
                    selectAllOnFocus: true,
                    onTap: () => discountCtrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: discountCtrl.text.length),
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
              CustomButton(label: 'บันทึก', onPressed: saveAction),
            ],
          );
        },
      ),
    );
  }
}
