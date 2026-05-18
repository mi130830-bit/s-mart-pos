import 'package:flutter/material.dart';

/// Result จาก DashboardDeleteDialog.show()
class DeleteOrderResult {
  final String reason;
  final bool returnStock;
  const DeleteOrderResult({required this.reason, required this.returnStock});
}

/// Dialog ยืนยันการยกเลิก/ลบบิล (Void) — คืนแค่ผลการยืนยัน ไม่ทำ business logic
class DashboardDeleteDialog {
  /// แสดง Dialog ยืนยันการลบบิล
  ///
  /// Returns [DeleteOrderResult] ถ้า user กด "ยืนยัน", null ถ้ากด "ยกเลิก"
  static Future<DeleteOrderResult?> show(
    BuildContext context, {
    required Map<String, dynamic> orderRow,
  }) async {
    final int orderId = int.tryParse(orderRow['id'].toString()) ?? 0;
    final String type = orderRow['type'] ?? 'ORDER';

    String selectedReason = 'คีย์ผิด';
    final formKey = GlobalKey<FormState>();
    bool returnStock = true;

    return showDialog<DeleteOrderResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(type == 'DEBT_PAYMENT'
              ? 'ยกเลิกการชำระหนี้?'
              : 'ยืนยันการยกเลิกบิล (Void)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type == 'DEBT_PAYMENT'
                    ? 'คุณต้องการลบรายการชำระหนี้ #$orderId ใช่หรือไม่?\n(ยอดหนี้จะถูกคืนกลับไปที่ลูกค้า)'
                    : 'คุณต้องการยกเลิกบิล #$orderId ใช่หรือไม่?'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'ระบุสาเหตุการยกเลิก (บังคับ)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'คีย์ผิด', child: Text('คีย์ผิด')),
                    DropdownMenuItem(
                        value: 'ลูกค้ายกเลิก', child: Text('ลูกค้ายกเลิก')),
                    DropdownMenuItem(
                        value: 'เปลี่ยนสินค้า', child: Text('เปลี่ยนสินค้า')),
                    DropdownMenuItem(
                        value: 'ชำระเงินผิดพลาด',
                        child: Text('ชำระเงินผิดพลาด')),
                    DropdownMenuItem(value: 'อื่นๆ', child: Text('อื่นๆ')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedReason = val);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณาเลือกสาเหตุ';
                    }
                    return null;
                  },
                ),
                if (type != 'DEBT_PAYMENT') ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('คืนยอดสต็อกสินค้า'),
                    value: returnStock,
                    onChanged: (v) =>
                        setState(() => returnStock = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Text(
                    'บิลจะถูกปรับสถานะเป็น VOID และไม่นำไปคำนวณยอดขาย',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('ไม่ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(
                    ctx,
                    DeleteOrderResult(
                      reason: selectedReason,
                      returnStock: returnStock,
                    ),
                  );
                }
              },
              child: const Text('ยืนยัน Void / ลบ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
