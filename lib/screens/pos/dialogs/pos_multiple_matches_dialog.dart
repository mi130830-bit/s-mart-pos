import 'package:flutter/material.dart';

import '../../../models/product.dart';

/// Dialog แสดงรายการสินค้าที่ตรงกับ barcode มากกว่า 1 รายการ
class PosMultipleMatchesDialog {
  static Future<void> show(
    BuildContext context, {
    required List<Product> matches,
    required double quantity,
    required Future<void> Function(Product product, double quantity) onSelected,
  }) async {
    await showDialog(
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
                  onSelected(p, quantity);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }
}
