import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../pos_state_manager.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/common/barcode_listener_wrapper.dart';
import '../../../widgets/common/custom_buttons.dart';

/// Dialog แสดงเมื่อสแกน Barcode ไม่พบสินค้าในระบบ
/// รองรับ Seamless Scan (สแกนสินค้าถัดไปขณะ Dialog เปิดอยู่)
class PosNotFoundDialog {
  static Future<void> show(
    BuildContext context, {
    required String barcode,
    required PosStateManager posState,
    required double qty,
    required Future<void> Function(String barcode, PosStateManager posState,
            double qty)
        onCreateProduct,
    required void Function(String barcode, PosStateManager posState,
            double qty)
        onQuickSale,
    required void Function(String newBarcode, PosStateManager posState)
        onBarcodeScanned,
    required bool Function(String key, String actionName) checkPermission,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BarcodeListenerWrapper(
        onBarcodeScanned: (newBarcode) {
          debugPrint('🚀 [Seamless Scan] Dialog intercepted: $newBarcode');
          Navigator.pop(ctx);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              onBarcodeScanned(newBarcode, posState);
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
                if (!checkPermission(
                    'manage_product', 'ลงทะเบียนสินค้าใหม่')) {
                  return;
                }
                Navigator.pop(ctx);
                onCreateProduct(barcode, posState, qty);
              },
            ),
            CustomButton(
              icon: Icons.sell,
              label: 'ขายระบุราคาเอง',
              backgroundColor: Colors.green,
              onPressed: () {
                if (!checkPermission('sale', 'ขายสินค้า')) {
                  return;
                }
                Navigator.pop(ctx);
                onQuickSale(barcode, posState, qty);
              },
            ),
            CustomButton(
              label: 'ยกเลิก',
              type: ButtonType.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง Alert สินค้าใกล้หมด (ใช้หลัง addToCart สำเร็จ)
  static void showLowStockAlert(
    BuildContext context, {
    required Product product,
  }) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (context.mounted) {
        AlertService.show(
          context: context,
          message:
              '⚠️ สินค้าใกล้หมด: ${product.name} (คงเหลือ: ${product.stockQuantity})',
          type: 'warning',
          duration: const Duration(seconds: 3),
        );
      }
    });
  }
}
