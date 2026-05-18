import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../pos_state_manager.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog ขายสินค้าชั่วคราวโดยระบุราคาเอง (กรณีสแกน barcode ไม่พบ)
class PosQuickSaleDialog {
  static Future<void> show(
    BuildContext context, {
    required String barcode,
    required PosStateManager posState,
    required double qty,
    required VoidCallback onComplete,
  }) async {
    final priceCtrl = TextEditingController();
    final nameCtrl =
        TextEditingController(text: 'สินค้าทั่วไป ($barcode)');

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
          points: 0,
        );
        await posState.addProductToCart(tempProduct, quantity: qty);
        if (context.mounted) Navigator.pop(context);
        onComplete();
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ขายสินค้าชั่วคราว'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: nameCtrl, label: 'ชื่อสินค้า'),
            const SizedBox(height: 12),
            CustomTextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              label: 'ราคาขาย',
              selectAllOnFocus: true,
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
      ),
    );
  }
}
