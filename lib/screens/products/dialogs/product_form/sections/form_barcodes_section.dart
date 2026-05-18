import 'package:flutter/material.dart';
import '../../../../../models/product_barcode.dart';
import '../../../../../widgets/common/custom_buttons.dart';
import '../../../../../widgets/common/custom_text_field.dart';

class FormBarcodesSection extends StatefulWidget {
  final List<ProductBarcode> extraBarcodes;
  final int productId;

  const FormBarcodesSection({
    super.key,
    required this.extraBarcodes,
    required this.productId,
  });

  @override
  State<FormBarcodesSection> createState() => _FormBarcodesSectionState();
}

class _FormBarcodesSectionState extends State<FormBarcodesSection> {
  Future<void> _addBarcode() async {
    final barcodeCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มหน่วยสินค้า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: barcodeCtrl,
              label: 'บาร์โค้ด (เช่น บาร์โค้ดแพ็ค)',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: unitCtrl,
              label: 'ชื่อหน่วย (เช่น แพ็ค, โหล)',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: priceCtrl,
              label: 'ราคาขายของหน่วยนี้',
              keyboardType: TextInputType.number,
              selectAllOnFocus: true, // ✅ Auto-select
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: qtyCtrl,
              label: 'จำนวนชิ้นในหน่วยนี้ (Conversion)',
              keyboardType: TextInputType.number,
              selectAllOnFocus: true, // ✅ Auto-select
            ),
          ],
        ),
        actions: [
          CustomButton(
            label: 'ยกเลิก',
            type: ButtonType.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            label: 'เพิ่ม',
            onPressed: () {
              if (barcodeCtrl.text.isEmpty || unitCtrl.text.isEmpty) return;
              setState(() {
                widget.extraBarcodes.add(ProductBarcode(
                  productId: widget.productId,
                  barcode: barcodeCtrl.text,
                  unitName: unitCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  quantity: double.tryParse(qtyCtrl.text) ?? 1,
                ));
              });
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'กำหนดหน่วยสินค้าย่อย (Multi-Unit/Packaging)',
                  style: TextStyle(color: Colors.purple[900]),
                ),
              ),
              CustomButton(
                onPressed: _addBarcode,
                icon: Icons.add,
                label: 'เพิ่มหน่วย',
                type: ButtonType.primary,
                backgroundColor: Colors.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: widget.extraBarcodes.isEmpty
              ? const Center(child: Text('ยังไม่มีหน่วยสินค้าเพิ่มเติม'))
              : ListView.separated(
                  itemCount: widget.extraBarcodes.length,
                  separatorBuilder: (ctx, i) =>
                      const Divider(height: 1, color: Colors.grey),
                  itemBuilder: (ctx, i) {
                    final b = widget.extraBarcodes[i];
                    return ListTile(
                      title: Text(
                          '${b.unitName} (${b.quantity.toStringAsFixed(0)} ชิ้น)'),
                      subtitle:
                          Text('Barcode: ${b.barcode} | ราคา: ${b.price}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            widget.extraBarcodes.removeAt(i);
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
