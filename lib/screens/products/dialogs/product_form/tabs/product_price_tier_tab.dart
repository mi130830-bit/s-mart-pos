// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductPriceTierTabExtension on _ProductFormDialogState {
  Widget _buildPriceTierContent() {
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
          child: _priceTiers.isEmpty
              ? Center(
                  child: Text('ยังไม่มีการกำหนดราคาระดับ',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : ListView.separated(
                  itemCount: _priceTiers.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final tier = _priceTiers[index];
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
                              onPressed: () {
                                setState(() {
                                  _priceTiers.removeAt(index);
                                });
                              },
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

  void _addPriceTier() {
    setState(() {
      _priceTiers.add(ProductPriceTier(
        id: 0,
        productId: widget.product?.id ?? 0,
        minQuantity: 10,
        price: 0,
        note: '',
      ));
    });
  }
}
