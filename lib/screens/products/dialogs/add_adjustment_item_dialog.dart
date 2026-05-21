import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../controllers/stock_adjustment_controller.dart';
import '../product_selection_dialog.dart';

class AddAdjustmentItemDialog extends ConsumerStatefulWidget {
  const AddAdjustmentItemDialog({super.key});

  @override
  ConsumerState<AddAdjustmentItemDialog> createState() =>
      _AddAdjustmentItemDialogState();
}

class _AddAdjustmentItemDialogState extends ConsumerState<AddAdjustmentItemDialog> {
  final _dialogFormKey = GlobalKey<FormState>();
  final TextEditingController _dialogCountedQtyCtrl = TextEditingController();
  final TextEditingController _dialogNoteCtrl = TextEditingController();
  Product? _dialogSelectedProduct;

  @override
  void dispose() {
    _dialogCountedQtyCtrl.dispose();
    _dialogNoteCtrl.dispose();
    super.dispose();
  }

  // สไตล์สำหรับ Input Field ที่ปรับให้ใหญ่ขึ้น
  InputDecoration _bigInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 16),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  TextStyle get _bigTextStyle => const TextStyle(fontSize: 18);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'เช็คสต็อก (Check Stock)',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _dialogFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // --- ส่วนเลือกสินค้า ---
                InkWell(
                  onTap: () async {
                    if (!context.mounted) return;
                    final controller = ref.read(stockAdjustmentProvider.notifier);
                    
                    final picked = await showDialog<Product>(
                      context: context,
                      builder: (c) => ProductSelectionDialog(
                          repo: controller.productRepo),
                    );
                    if (picked != null) {
                      setState(() {
                        _dialogSelectedProduct = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: _bigInputDecoration('สินค้า').copyWith(
                      suffixIcon: const Icon(Icons.arrow_drop_down, size: 28),
                    ),
                    child: Text(
                      _dialogSelectedProduct != null
                          ? _dialogSelectedProduct!.name
                          : 'แตะเพื่อเลือกสินค้า...',
                      style: _bigTextStyle.copyWith(
                        color: _dialogSelectedProduct == null
                            ? Colors.grey.shade600
                            : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (_dialogSelectedProduct != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('จำนวนในระบบ (System):',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          _dialogSelectedProduct!.stockQuantity
                              .toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // --- ช่องจำนวนที่นับได้ ---
                CustomTextField(
                  controller: _dialogCountedQtyCtrl,
                  label: 'จำนวนที่นับได้จริง (Counted)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'กรุณาระบุจำนวนที่นับได้';
                    }
                    if (double.tryParse(v) == null) {
                      return 'ตัวเลขไม่ถูกต้อง';
                    }
                    if (double.parse(v) < 0) {
                      return 'ต้องไม่ติดลบ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // --- ช่องหมายเหตุ ---
                CustomTextField(
                  controller: _dialogNoteCtrl,
                  label: 'หมายเหตุ',
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      actions: [
        CustomButton(
          label: 'ยกเลิก',
          type: ButtonType.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: 'เพิ่มรายการ',
          type: ButtonType.primary,
          onPressed: () {
            if (_dialogSelectedProduct != null &&
                _dialogFormKey.currentState!.validate()) {
              double counted = double.parse(_dialogCountedQtyCtrl.text);
              double system = _dialogSelectedProduct!.stockQuantity;

              final controller = ref.read(stockAdjustmentProvider.notifier);
              controller.addPendingItem(
                AdjustmentItem(
                  product: _dialogSelectedProduct!,
                  systemQty: system,
                  countedQty: counted,
                  note: _dialogNoteCtrl.text,
                ),
              );
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
