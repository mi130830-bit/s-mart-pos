import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../widgets/common/custom_buttons.dart';

class StockInSummaryPanel extends StatelessWidget {
  final double subtotal;
  final double vatAmount;
  final double grandTotal;
  final int vatType;
  final String poStatus;
  final bool hasItems;
  final VoidCallback onSaveOrder;
  final VoidCallback onReceiveStock;

  const StockInSummaryPanel({
    super.key,
    required this.subtotal,
    required this.vatAmount,
    required this.grandTotal,
    required this.vatType,
    required this.poStatus,
    required this.hasItems,
    required this.onSaveOrder,
    required this.onReceiveStock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (vatType != 2) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                  vatType == 0
                      ? 'ยอดรวม (รวม VAT):'
                      : 'ยอดรวมก่อนภาษี:',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(NumberFormat('#,##0.00').format(subtotal),
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('ภาษีมูลค่าเพิ่ม (7%):',
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(width: 8),
              Text(NumberFormat('#,##0.00').format(vatAmount),
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
          const Divider(),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'ยอดรวมสุทธิ: ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '฿${NumberFormat('#,##0.00').format(grandTotal)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Action Buttons
        Row(
          children: [
            if (poStatus == 'NEW' || poStatus == 'DRAFT') ...[
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: CustomButton(
                    onPressed: onSaveOrder,
                    icon: Icons.save,
                    label: 'บันทึกใบสั่งซื้อ (ยังไม่เข้าสต็อก)',
                    type: ButtonType.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: SizedBox(
                height: 50,
                child: CustomButton(
                  onPressed: hasItems ? onReceiveStock : null,
                  icon: Icons.archive,
                  label: (poStatus == 'RECEIVED')
                      ? 'บันทึกการแก้ไข'
                      : 'รับสินค้าเข้าสต็อก',
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
