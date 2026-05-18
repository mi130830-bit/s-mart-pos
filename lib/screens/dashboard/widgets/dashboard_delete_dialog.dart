import 'package:flutter/material.dart';

import '../../../repositories/sales_repository.dart';
import '../../../repositories/debtor_repository.dart';
import '../../../services/alert_service.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/dialogs/admin_pin_dialog.dart';

/// Dialog ยืนยันการยกเลิก/ลบบิล (Void)
///
/// ส่ง [onDeleted] callback เมื่อการลบสำเร็จ
Future<void> showConfirmDeleteOrderDialog({
  required BuildContext context,
  required Map<String, dynamic> orderRow,
  required SalesRepository salesRepo,
  required DebtorRepository debtRepo,
  required Future<bool> Function(String action) checkPermission,
  required VoidCallback onDeleted,
}) async {
  if (!await checkPermission('history_delete_bill')) return;
  if (!context.mounted) return;

  final int orderId = int.tryParse(orderRow['id'].toString()) ?? 0;
  final String type = orderRow['type'] ?? 'ORDER';

  String? selectedReason = 'คีย์ผิด';
  final formKey = GlobalKey<FormState>();
  bool returnStock = true;

  final confirm = await showDialog<bool>(
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
                  DropdownMenuItem(value: 'คีย์ผิด', child: Text('คีย์ผิด')),
                  DropdownMenuItem(
                      value: 'ลูกค้ายกเลิก', child: Text('ลูกค้ายกเลิก')),
                  DropdownMenuItem(
                      value: 'เปลี่ยนสินค้า', child: Text('เปลี่ยนสินค้า')),
                  DropdownMenuItem(
                      value: 'ชำระเงินผิดพลาด',
                      child: Text('ชำระเงินผิดพลาด')),
                  DropdownMenuItem(value: 'อื่นๆ', child: Text('อื่นๆ')),
                ],
                onChanged: (val) => setState(() => selectedReason = val),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณาเลือกสาเหตุ';
                  return null;
                },
              ),
              if (type != 'DEBT_PAYMENT') ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('คืนยอดสต็อกสินค้า'),
                  value: returnStock,
                  onChanged: (v) => setState(() => returnStock = v ?? false),
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
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ไม่ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('ยืนยัน Void / ลบ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );

  if (confirm != true || !context.mounted) return;

  // ✅ Security: ถ้าเปิด Toggle "บังคับรหัส Admin เมื่อลบบิล"
  if (SettingsService().requireAdminForVoid) {
    final authorized = await AdminPinDialog.show(
      context,
      title: 'ยืนยันสิทธิ์ลบบิล',
      message: 'กรุณากรอกรหัส Admin เพื่อยืนยันการยกเลิกบิล #$orderId',
    );
    if (!authorized || !context.mounted) return;
  }

  if (type == 'DEBT_PAYMENT') {
    try {
      final success = await debtRepo.deleteTransaction(orderId);
      if (success && context.mounted) {
        onDeleted();
        AlertService.show(
            context: context,
            message: 'ลบรายการชำระหนี้เรียบร้อย',
            type: 'success');
      }
    } catch (e) {
      if (context.mounted) {
        AlertService.show(
            context: context,
            message: e.toString().replaceAll('Exception: ', ''),
            type: 'error');
      }
    }
  } else {
    try {
      await salesRepo.voidOrder(orderId,
          reason: selectedReason ?? 'คีย์ผิด', returnToStock: returnStock);
      if (context.mounted) {
        onDeleted();
        AlertService.show(
            context: context, message: 'ยกเลิกบิลเรียบร้อย', type: 'success');
      }
    } catch (e) {
      if (context.mounted) {
        AlertService.show(
            context: context,
            message: 'เกิดข้อผิดพลาด: $e',
            type: 'error');
      }
    }
  }
}
