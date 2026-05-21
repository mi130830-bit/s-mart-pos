import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../pos_state_manager.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog แจ้งเตือนสต็อกสินค้าไม่พอ พร้อมตัวเลือกเพิ่มเท่าที่มี
class PosStockInsufficientDialog {
  static Future<void> show(
    BuildContext context, {
    required String errorMsg,
    required Product product,
    required PosStateNotifier posState,
    double? overridePrice,
    String? overrideUnit,
    double? overrideConversionFactor,
    required VoidCallback onComplete,
  }) async {
    // Parse available stock from error message
    // Format: 'สต๊อกสินค้า "..." ไม่พอ (เหลือ: X ชิ้น, ต้องการ: Y ชิ้น)'
    double availableQty = 0;
    try {
      final match =
          RegExp(r'เหลือ: (\d+\.?\d*) ชิ้น').firstMatch(errorMsg);
      if (match != null) {
        availableQty = double.tryParse(match.group(1)!) ?? 0;
      }
    } catch (_) {}

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('สต็อกไม่พอ!',
                style: TextStyle(color: Colors.orange)),
          ],
        ),
        content: Text(
          'สินค้า "${product.name}" คงเหลือเพียง ${availableQty.toStringAsFixed(0)} ชิ้น เท่านั้น\n\n'
          'ต้องการเพิ่ม ${availableQty.toStringAsFixed(0)} ชิ้น (เท่าที่มี) หรือยกเลิก?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก',
                style: TextStyle(color: Colors.grey)),
          ),
          if (availableQty > 0)
            CustomButton(
              icon: Icons.add_shopping_cart,
              label: 'เพิ่ม ${availableQty.toStringAsFixed(0)} ชิ้น',
              backgroundColor: Colors.orange,
              onPressed: () async {
                Navigator.pop(ctx);
                await posState.addProductToCart(
                  product,
                  quantity: availableQty,
                  overridePrice: overridePrice,
                  overrideUnit: overrideUnit,
                  overrideConversionFactor: overrideConversionFactor,
                );
                if (context.mounted) {
                  AlertService.show(
                    context: context,
                    message:
                        'เพิ่ม ${product.name} x${availableQty.toStringAsFixed(0)} ชิ้น (เท่าที่มีในสต็อก)',
                    type: 'warning',
                    duration: const Duration(seconds: 2),
                  );
                }
                onComplete();
              },
            ),
        ],
      ),
    );
  }
}
