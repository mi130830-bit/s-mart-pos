import 'package:flutter/material.dart';
import '../../../../../models/product_price_tier.dart';
import '../../../../../widgets/common/custom_buttons.dart';
import '../../../../../widgets/common/custom_text_field.dart';

class FormPriceTiersSection extends StatefulWidget {
  final List<ProductPriceTier> priceTiers;
  final int productId;

  const FormPriceTiersSection({
    super.key,
    required this.priceTiers,
    required this.productId,
  });

  @override
  State<FormPriceTiersSection> createState() => _FormPriceTiersSectionState();
}

class _FormPriceTiersSectionState extends State<FormPriceTiersSection> {
  void _addPriceTier() {
    setState(() {
      widget.priceTiers.add(ProductPriceTier(
        id: 0,
        productId: widget.productId,
        minQuantity: 10,
        price: 0,
        note: '',
      ));
    });
  }

  void _removePriceTier(int index) {
    setState(() {
      widget.priceTiers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'กำหนดราคาขายตามจำนวนขั้นบันได (Volume Pricing)',
                  style: TextStyle(color: Colors.orange[900]),
                ),
              ),
              CustomButton(
                onPressed: _addPriceTier,
                icon: Icons.add,
                label: 'เพิ่มระดับราคา',
                type: ButtonType.primary,
                backgroundColor: Colors.orange[700],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey[800],
          child: const Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text('จำนวนขั้นต่ำ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 3,
                  child: Text('ราคาต่อหน่วย',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 4,
                  child: Text('หมายเหตุ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 40,
                  child: Text('ลบ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),
        // List
        Expanded(
          child: widget.priceTiers.isEmpty
              ? Center(
                  child: Text('ยังไม่มีการกำหนดราคาระดับ',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : ListView.separated(
                  itemCount: widget.priceTiers.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final tier = widget.priceTiers[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                      child: Row(
                        children: [
                          // Min Qty
                          Expanded(
                            flex: 3,
                            child: CustomTextField(
                              initialValue: tier.minQuantity.toString(),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                tier.minQuantity = double.tryParse(val) ?? 0;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Price
                          Expanded(
                            flex: 3,
                            child: CustomTextField(
                              initialValue: tier.price.toString(),
                              keyboardType: TextInputType.number,
                              prefixText: '฿ ',
                              onChanged: (val) {
                                tier.price = double.tryParse(val) ?? 0;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Note
                          Expanded(
                            flex: 4,
                            child: CustomTextField(
                              initialValue: tier.note,
                              hint: 'เช่น ราคาส่งยกลัง',
                              onChanged: (val) {
                                tier.note = val;
                              },
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removePriceTier(index),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
