import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/alert_service.dart';
import '../../../../widgets/common/custom_buttons.dart';

class EditReceivedQtyDialog extends StatefulWidget {
  final int poId;
  final String orderRef;
  final List<Map<String, dynamic>> items;
  final int vatType;

  const EditReceivedQtyDialog({
    super.key,
    required this.poId,
    required this.orderRef,
    required this.items,
    required this.vatType,
  });

  @override
  State<EditReceivedQtyDialog> createState() => _EditReceivedQtyDialogState();
}

class _EditReceivedQtyDialogState extends State<EditReceivedQtyDialog> {
  // controllers per item index
  late List<TextEditingController> _qtyControllers;
  late List<TextEditingController> _costControllers;

  @override
  void initState() {
    super.initState();
    _qtyControllers = widget.items.map((item) {
      final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
      return TextEditingController(
          text: qty.toString().replaceAll(RegExp(r'([.]*0+)(?!\d)'), ''));
    }).toList();

    _costControllers = widget.items.map((item) {
      final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
      return TextEditingController(
          text: cost.toString().replaceAll(RegExp(r'([.]*0+)(?!\d)'), ''));
    }).toList();
  }

  @override
  void dispose() {
    for (var c in _qtyControllers) {
      c.dispose();
    }
    for (var c in _costControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _calcSubtotal() {
    double total = 0.0;
    for (var i = 0; i < widget.items.length; i++) {
      final qty = double.tryParse(_qtyControllers[i].text.replaceAll(',', '')) ?? 0.0;
      final cost = double.tryParse(_costControllers[i].text.replaceAll(',', '')) ?? 0.0;
      total += qty * cost;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setStateDialog) {
      final subtotal = _calcSubtotal();
      double vatAmount = 0.0;
      double grandTotal = subtotal;
      if (widget.vatType == 0) {
        // รวมภาษี
        vatAmount = subtotal * 7 / 107;
      } else if (widget.vatType == 1) {
        // แยกภาษี
        vatAmount = subtotal * 0.07;
        grandTotal = subtotal + vatAmount;
      }

      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'แก้ไขจำนวนรับเข้า: ${widget.orderRef}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 750,
          height: 520,
          child: Column(
            children: [
              // ─── คำเตือน ───────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'การแก้ไขจะคืน Stock เดิม แล้วบันทึก Stock ใหม่ตามจำนวนที่แก้ไข',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text('สินค้า',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text('จำนวน',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text('ต้นทุน/หน่วย',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text('รวม',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ─── Items ─────────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final productName = item['productName']?.toString() ?? '-';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          // ชื่อสินค้า
                          Expanded(
                            flex: 4,
                            child: Text(
                              productName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // จำนวน
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _qtyControllers[index],
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.indigo.shade400,
                                      width: 1.5),
                                ),
                                hintText: '0',
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ต้นทุน
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _costControllers[index],
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.indigo.shade400,
                                      width: 1.5),
                                ),
                                hintText: '0.00',
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // รวม
                          Expanded(
                            flex: 2,
                            child: Builder(builder: (_) {
                              final qty = double.tryParse(
                                      _qtyControllers[index].text.trim().replaceAll(',', '')) ??
                                  0.0;
                              final cost = double.tryParse(
                                      _costControllers[index].text.trim().replaceAll(',', '')) ??
                                  0.0;
                              return Text(
                                NumberFormat('#,##0.00').format(qty * cost),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.indigo),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ─── สรุปยอด ────────────────────────────────────────────────────
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.vatType != 2) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.vatType == 0
                                ? 'ยอดรวม (รวม VAT):'
                                : 'ยอดรวมก่อนภาษี:',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            NumberFormat('#,##0.00').format(subtotal),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('ภาษีมูลค่าเพิ่ม (7%):',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Text(NumberFormat('#,##0.00').format(vatAmount),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('ยอดรวมสุทธิ:',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(
                          '฿${NumberFormat('#,##0.00').format(grandTotal)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo),
                        ),
                      ],
                    ),
                  ],
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
              // ตรวจสอบว่าจำนวนที่ใส่ถูกต้อง
              final List<Map<String, dynamic>> result = [];
              for (var i = 0; i < widget.items.length; i++) {
                final item = widget.items[i];
                final qty =
                    double.tryParse(_qtyControllers[i].text.trim().replaceAll(',', '')) ?? 0.0;
                final cost =
                    double.tryParse(_costControllers[i].text.trim().replaceAll(',', '')) ?? 0.0;

                if (qty < 0 || cost < 0) {
                  AlertService.show(
                    context: context,
                    message: 'จำนวนและต้นทุนต้องมากกว่าหรือเท่ากับ 0',
                    type: 'warning',
                  );
                  return;
                }

                result.add({
                  'productId': int.tryParse(item['productId'].toString()) ?? 0,
                  'productName': item['productName']?.toString() ?? '',
                  'quantity': qty,
                  'costPrice': cost,
                });
              }

              if (result.every((r) =>
                  (double.tryParse(r['quantity'].toString()) ?? 0.0) == 0)) {
                AlertService.show(
                  context: context,
                  message: 'จำนวนรับเข้าต้องมากกว่า 0 อย่างน้อย 1 รายการ',
                  type: 'warning',
                );
                return;
              }

              Navigator.pop(context, result);
            },
            label: 'บันทึกการแก้ไข',
            icon: Icons.save,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ],
      );
    });
  }
}
