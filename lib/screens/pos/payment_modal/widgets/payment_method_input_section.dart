import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../pos_payment_panel.dart'; // For PaymentType enum

class PaymentMethodInputSection extends StatelessWidget {
  final TextEditingController amountCtrl;
  final FocusNode amountFocusNode;
  final PaymentType selectedPaymentType;
  final bool isVerifyingSlip;
  final String? slipVerificationMsg;
  final bool? slipVerificationSuccess;
  final TextEditingController noteCtrl;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onAmountSubmitted;
  final ValueChanged<PaymentType> onPaymentTypeChanged;
  final VoidCallback onVerifySlip;

  const PaymentMethodInputSection({
    super.key,
    required this.amountCtrl,
    required this.amountFocusNode,
    required this.selectedPaymentType,
    required this.isVerifyingSlip,
    required this.slipVerificationMsg,
    required this.slipVerificationSuccess,
    required this.noteCtrl,
    required this.onAmountChanged,
    required this.onAmountSubmitted,
    required this.onPaymentTypeChanged,
    required this.onVerifySlip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ใสจำนวนเงนทรบมา",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: amountCtrl,
                focusNode: amountFocusNode,
                textAlign: TextAlign.center,
                readOnly: selectedPaymentType == PaymentType.credit,
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: selectedPaymentType == PaymentType.credit
                        ? Colors.grey
                        : Colors.blue),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: selectedPaymentType == PaymentType.credit
                      ? Colors.grey.shade200
                      : Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  prefixText: selectedPaymentType == PaymentType.credit ? '' : '฿ ',
                  labelText: selectedPaymentType == PaymentType.credit
                      ? 'ไม่ต้องใส่ยอดเงิน (บันทึกหนี้)'
                      : 'รับเงินสด (Space = ยอดพอดี)',
                  hintText: selectedPaymentType == PaymentType.credit ? '-' : '0.00',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onSubmitted: onAmountSubmitted,
                onChanged: onAmountChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedPaymentType == PaymentType.qr) ...[
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: isVerifyingSlip ? null : onVerifySlip,
                icon: isVerifyingSlip
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(isVerifyingSlip
                    ? 'กำลังตรวจสอบ...'
                    : 'แนบสลิป (Verify Slip)'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              )),
            ],
          ),
          if (slipVerificationMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(
                    slipVerificationSuccess == true
                        ? Icons.check_circle
                        : Icons.error,
                    color: slipVerificationSuccess == true
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(slipVerificationMsg!,
                          style: TextStyle(
                              color: slipVerificationSuccess == true
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold))),
                ],
              ),
            )
        ],
        const SizedBox(height: 24),
        SegmentedButton<PaymentType>(
          segments: PaymentType.values
              .map((p) => ButtonSegment(
                  value: p, label: Text(p.label), icon: Icon(p.icon)))
              .toList(),
          selected: {selectedPaymentType},
          onSelectionChanged: (val) => onPaymentTypeChanged(val.first),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              labelText: 'หมายเหตุเพิ่มเติม (Note)',
              hintText: 'Note',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_alt_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
