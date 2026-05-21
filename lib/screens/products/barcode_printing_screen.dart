import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import 'controllers/barcode_printing_controller.dart';

class BarcodePrintingScreen extends ConsumerWidget {
  const BarcodePrintingScreen({super.key});

  Future<void> _showEditQuantityDialog(BuildContext context, BarcodePrintingController controller, int productId, int currentQty) async {
    final qtyController = TextEditingController(text: '$currentQty');
    qtyController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: qtyController.text.length,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ระบุจำนวน'),
        content: CustomTextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          label: 'จำนวนบาร์โค้ด',
          onSubmitted: (_) {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'ยกเลิก',
            type: ButtonType.secondary,
          ),
          CustomButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            label: 'ตกลง',
            type: ButtonType.primary,
          ),
        ],
      ),
    );

    final newVal = int.tryParse(qtyController.text);
    if (newVal != null) {
      controller.updateCountExact(productId, newVal);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(barcodePrintingProvider);
    final controller = ref.read(barcodePrintingProvider.notifier);
    final selectedCount = state.printCounts.values.fold(0, (sum, val) => sum + val);

    return Scaffold(
      appBar: AppBar(
        title: const Text('พิมพ์บาร์โค้ด (Print Barcode)'),
      ),
      body: Row(
        children: [
          // ---------------- LEFT SIDE: Product Selection ----------------
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey.shade200,
                  width: double.infinity,
                  child: const Text(
                    '1. เลือกสินค้าที่ต้องการ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomTextField(
                    controller: controller.searchController,
                    onChanged: controller.onSearchChanged,
                    hint: 'ค้นหาชื่อสินค้าหรือรหัสบาร์โค้ด...',
                    prefixIcon: Icons.search,
                  ),
                ),

                // Product List
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: state.filteredProducts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = state.filteredProducts[index];
                            final inQueue = state.printCounts.containsKey(p.id);
                            final qty = state.printCounts[p.id] ?? 0;

                            return ListTile(
                              title: Text(p.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${p.barcode ?? "-"} | ${p.retailPrice} ฿',
                                  style: TextStyle(color: Colors.grey[600])),
                              trailing: inQueue
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'เลือกแล้ว ($qty)',
                                        style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : CustomButton(
                                      onPressed: () => controller.updateCount(p.id, 1),
                                      label: 'เพิ่ม',
                                      type: ButtonType.secondary,
                                    ),
                              onTap: () {
                                // Tap entire row to add
                                controller.updateCount(p.id, 1);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // ---------------- RIGHT SIDE: Queue & Action ----------------
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.blue.shade50,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '2. รายการที่เลือก (คิวการพิมพ์)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (state.printCounts.isNotEmpty)
                        CustomButton(
                          onPressed: () {
                            controller.clearQueue();
                          },
                          icon: Icons.delete_sweep,
                          label: 'ล้างทั้งหมด',
                          type: ButtonType.danger,
                        )
                    ],
                  ),
                ),

                // Selected List
                Expanded(
                  child: state.printCounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_disabled,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              Text('ยังไม่มีรายการสินค้า',
                                  style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: state.printCounts.length,
                          itemBuilder: (context, index) {
                            final productId = state.printCounts.keys.elementAt(index);
                            final qty = state.printCounts[productId]!;

                            // Retrieve from cache, or dummy if missing
                            final product = state.selectedProductsCache[productId] ??
                                Product(
                                  id: productId,
                                  name: 'Unknown Product',
                                  barcode: '',
                                  costPrice: 0,
                                  retailPrice: 0,
                                  vatType: 1,
                                  points: 0,
                                  stockQuantity: 0,
                                  productType: 0,
                                );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(product.barcode ?? '-',
                                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.grey),
                                      onPressed: () => controller.updateCount(productId, -1),
                                    ),
                                    InkWell(
                                      onTap: () => _showEditQuantityDialog(context, controller, productId, qty),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        width: 50,
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$qty',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                                      onPressed: () => controller.updateCount(productId, 1),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        controller.updateCountExact(productId, 0);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Orientation Selector
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('แนวการพิมพ์:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              value: state.orientation,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'landscape',
                                  child: Row(
                                    children: [
                                      Icon(Icons.landscape, size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('แนวนอน (Landscape)'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'portrait',
                                  child: Row(
                                    children: [
                                      Icon(Icons.portrait, size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('แนวตั้ง (Portrait)'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  controller.setOrientation(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('จำนวนรายการที่เลือก:', style: TextStyle(fontSize: 14)),
                          Text('${state.printCounts.length}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('จำนวนสติ๊กเกอร์ทั้งหมด:', style: TextStyle(fontSize: 16)),
                          Text('$selectedCount',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: CustomButton(
                          onPressed: state.printCounts.isEmpty
                              ? null
                              : () => controller.handlePrint(context),
                          icon: Icons.print,
                          label: 'สั่งพิมพ์บาร์โค้ด',
                          type: ButtonType.primary,
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
