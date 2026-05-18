import 'package:flutter/material.dart';

import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog ให้ผู้ใช้ระบุจำนวนสินค้า (F1)
class PosQuantityDialog {
  static Future<void> show(
    BuildContext context, {
    required void Function(String val) onConfirm,
  }) async {
    final inputCtrl = TextEditingController();

    await showDialog(
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
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              onSubmitted: (_) {
                Navigator.pop(ctx);
                onConfirm(inputCtrl.text);
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
                onConfirm(inputCtrl.text);
              }),
        ],
      ),
    );
  }
}
