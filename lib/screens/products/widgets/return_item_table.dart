import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/common/custom_text_field.dart';
import '../controllers/stock_return_controller.dart';

class ReturnItemTable extends ConsumerWidget {
  const ReturnItemTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockReturnProvider);
    final controller = ref.read(stockReturnProvider.notifier);
    final returnItems = state.returnItems;

    return Column(
      children: [
        // 1. Table Header
        Container(
          decoration: const BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: const Row(
            children: [
              SizedBox(
                  width: 40,
                  child: Text('#',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('อ้างอิงบิล (Ref)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 3,
                  child: Text('สินค้า (Product)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 1,
                  child: Text('จำนวน',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('ราคา/หน่วย',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              Expanded(
                  flex: 2,
                  child: Text('รวมเงินคืน',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))),
              SizedBox(
                  width: 50,
                  child: Center(
                      child: Text('ลบ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)))),
            ],
          ),
        ),

        // 2. Table Content
        Expanded(
          child: returnItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_shopping_cart_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('ไม่มีรายการคืน',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: returnItems.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = returnItems[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? Colors.white
                            : Colors.orange.withValues(alpha: 0.05),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text('${index + 1}')),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('#${item.orderId}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange)),
                                Text(item.customerName,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(item.productName,
                                style: const TextStyle(fontSize: 14)),
                          ),
                          Expanded(
                            flex: 1,
                            child: CustomTextField(
                              initialValue: item.returnQty.toString(),
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                final v = double.tryParse(val) ?? 0;
                                if (v > 0) {
                                  controller.updateReturnQty(index, v);
                                }
                              },
                            ),
                          ),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  NumberFormat('#,##0.00').format(item.price),
                                  textAlign: TextAlign.right)),
                          Expanded(
                              flex: 2,
                              child: Text(
                                NumberFormat('#,##0.00')
                                    .format(item.totalRefund),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              )),
                          SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => controller.removeReturnEntry(index),
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
