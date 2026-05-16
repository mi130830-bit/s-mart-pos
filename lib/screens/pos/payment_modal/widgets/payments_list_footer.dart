import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../../../../models/payment_record.dart';
import '../../../../models/delivery_type.dart';
import '../../../../widgets/common/custom_buttons.dart';
import '../../pos_payment_panel.dart'; // For PaymentType enum

class PaymentsListFooter extends StatelessWidget {
  final List<PaymentRecord> payments;
  final DeliveryType deliveryType;
  final bool shouldPrint;
  final bool isLoading;
  final bool isFullyPaid;
  final PaymentType selectedPaymentType;
  final Decimal receivedAmount;
  final ValueChanged<int> onRemovePayment;
  final ValueChanged<DeliveryType> onDeliveryTypeChanged;
  final ValueChanged<bool?> onShouldPrintChanged;
  final VoidCallback onProcessFinish;
  final VoidCallback onAddPayment;

  const PaymentsListFooter({
    super.key,
    required this.payments,
    required this.deliveryType,
    required this.shouldPrint,
    required this.isLoading,
    required this.isFullyPaid,
    required this.selectedPaymentType,
    required this.receivedAmount,
    required this.onRemovePayment,
    required this.onDeliveryTypeChanged,
    required this.onShouldPrintChanged,
    required this.onProcessFinish,
    required this.onAddPayment,
  });

  String _getLabelForMethod(String method) {
    try {
      return PaymentType.values.firstWhere((e) => e.name == method).label;
    } catch (_) {
      return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (payments.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12)),
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final p = payments[i];
                return Chip(
                  label: Text("${_getLabelForMethod(p.method)}: ฿${p.amount}"),
                  onDeleted: () => onRemovePayment(i),
                );
              },
            ),
          ),
        const Divider(),
        Row(
          children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('การจัดส่ง:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<DeliveryType>(
                  segments: const [
                    ButtonSegment(
                        value: DeliveryType.none,
                        label: Text('หน้าร้าน'),
                        icon: Icon(Icons.store)),
                    ButtonSegment(
                        value: DeliveryType.delivery,
                        label: Text('จัดส่ง'),
                        icon: Icon(Icons.local_shipping)),
                    ButtonSegment(
                        value: DeliveryType.pickup,
                        label: Text('หลังร้าน'),
                        icon: Icon(Icons.shopping_basket)),
                  ],
                  selected: {deliveryType},
                  onSelectionChanged: (val) => onDeliveryTypeChanged(val.first),
                  style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact),
                ),
              ],
            )),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('พิมพ์ใบเสร็จ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: shouldPrint,
                    onChanged: onShouldPrintChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              width: 160,
              child: CustomButton(
                onPressed: (isFullyPaid ||
                            selectedPaymentType == PaymentType.credit) &&
                        !isLoading
                    ? onProcessFinish
                    : null,
                backgroundColor: selectedPaymentType == PaymentType.credit
                    ? Colors.orange
                    : Colors.green,
                icon: isLoading ? null : Icons.check_circle,
                label: selectedPaymentType == PaymentType.credit
                    ? 'บันทึกหนี้'
                    : 'เสร็จสิ้น',
                isLoading: isLoading,
              ),
            ),
            // ✅ Add Partial Payment Button (Always visible if amount > 0)
            if (!isFullyPaid &&
                selectedPaymentType != PaymentType.credit &&
                receivedAmount > Decimal.zero) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                width: 140,
                child: OutlinedButton.icon(
                  onPressed: onAddPayment,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('รับเงินเพิ่ม\n(Split)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ]
          ],
        )
      ],
    );
  }
}
