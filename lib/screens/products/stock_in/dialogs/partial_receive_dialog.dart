import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/alert_service.dart';
import '../../../../widgets/common/custom_buttons.dart';
import '../models/stock_in_item.dart';

class PartialReceiveDialog extends StatefulWidget {
  final List<StockInItem> items;
  const PartialReceiveDialog({super.key, required this.items});

  @override
  State<PartialReceiveDialog> createState() => _PartialReceiveDialogState();
}

class _PartialReceiveDialogState extends State<PartialReceiveDialog> {
  final Map<int, bool> _selected = {};
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, double> _remainingMap = {};

  @override
  void initState() {
    super.initState();
    for (var item in widget.items) {
      double remaining = item.quantity - item.receivedQuantity;
      if (remaining < 0) remaining = 0;

      // Default checked if there is remaining items
      bool autoSelect = remaining > 0;
      _selected[item.product.id] = autoSelect;
      _remainingMap[item.product.id] = remaining;

      // Default text = remaining (to receive all remaining)
      _qtyControllers[item.product.id] = TextEditingController(
          text:
              remaining.toString().replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), ""));
    }
  }

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เลือกรายการที่รับสินค้า (Partial Receive)'),
      content: SizedBox(
        width: 700, // Wider for columns
        height: 500,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 40), // Checkbox space
                  Expanded(
                      flex: 3,
                      child: Text('สินค้า',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text('สั่งซื้อ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                  Expanded(
                      child: Text('รับแล้ว',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green))),
                  Expanded(
                      child: Text('ค้างรับ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red))),
                  Expanded(
                      flex: 2,
                      child: Text('รับครั้งนี้',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo))),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isChecked = _selected[item.product.id] ?? false;
                  final remaining = _remainingMap[item.product.id] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          onChanged: remaining > 0
                              ? (val) {
                                  setState(() {
                                    _selected[item.product.id] = val ?? false;
                                  });
                                }
                              : null, // Disable check if completed
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(item.product.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: Text(
                              NumberFormat('#,##0.##').format(item.quantity),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                        ),
                        Expanded(
                          child: Text(
                              NumberFormat('#,##0.##')
                                  .format(item.receivedQuantity),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.green)),
                        ),
                        Expanded(
                          child: Text(
                              NumberFormat('#,##0.##').format(remaining),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              controller: _qtyControllers[item.product.id],
                              enabled: isChecked,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        CustomButton(
          onPressed: () => Navigator.pop(context),
          label: 'ยกเลิก',
          type: ButtonType.secondary,
        ),
        CustomButton(
          onPressed: () {
            // Collect Data
            final List<Map<String, dynamic>> result = [];
            for (var item in widget.items) {
              if (_selected[item.product.id] == true) {
                final qtyStr = _qtyControllers[item.product.id]?.text ?? '0';
                final qty = double.tryParse(qtyStr) ?? 0;
                if (qty > 0) {
                  result.add({
                    'productId': item.product.id,
                    'productName': item.product.name,
                    'quantity': qty, // This is 'Receive Now' qty
                    'costPrice': item.costPrice,
                  });
                }
              }
            }

            if (result.isEmpty) {
              AlertService.show(
                  context: context,
                  message: 'กรุณาเลือกรายการที่จะรับสินค้า',
                  type: 'warning');
              return;
            }

            Navigator.pop(context, result);
          },
          label: 'ยืนยันการรับสินค้า',
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
