import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog ให้ผู้ใช้ระบุน้ำหนักสินค้าประเภทชั่งน้ำหนัก
class PosWeighingDialog {
  static Future<void> show(
    BuildContext context, {
    required Product product,
    required Future<void> Function(Product product, double weight) onConfirm,
  }) async {
    final weightCtrl = TextEditingController();

    await showDialog(
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
                  onConfirm(product, w);
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
                  onConfirm(product, w);
                }
              }),
        ],
      ),
    );
  }
}
