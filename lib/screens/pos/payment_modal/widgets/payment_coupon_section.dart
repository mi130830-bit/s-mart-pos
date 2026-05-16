import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../repositories/reward_repository.dart';

class PaymentCouponSection extends StatelessWidget {
  final TextEditingController couponCtrl;
  final bool couponApplied;
  final bool isValidatingCoupon;
  final CouponValidationResult? couponResult;
  final VoidCallback onClearCoupon;
  final VoidCallback onValidateCoupon;
  final ValueChanged<String> onChanged;

  const PaymentCouponSection({
    super.key,
    required this.couponCtrl,
    required this.couponApplied,
    required this.isValidatingCoupon,
    required this.couponResult,
    required this.onClearCoupon,
    required this.onValidateCoupon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Coupon Input Row
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: couponCtrl,
              textCapitalization: TextCapitalization.characters,
              enabled: !couponApplied,
              decoration: InputDecoration(
                labelText: '🎟️ รหัสคูปองส่วนลด',
                hintText: 'สแกน QR หรือพิมพ์รหัส เช่น SMR-XXXX-XXXX',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.discount_outlined),
                suffixIcon: couponApplied
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: onClearCoupon,
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: couponApplied,
                fillColor: couponApplied ? Colors.green.shade50 : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color:
                          couponApplied ? Colors.green : Colors.grey.shade400),
                ),
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onValidateCoupon(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: couponApplied || isValidatingCoupon
                ? null
                : onValidateCoupon,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: isValidatingCoupon
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('ตรวจสอบ', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
      // Coupon validation result
      if (couponResult != null && !couponResult!.isValid)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Text(couponResult!.error ?? '',
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ]),
        ),
      if (couponApplied && couponResult != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.discount, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text('คูปอง: ${couponResult!.couponCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Text(
                  '- ฿${NumberFormat("#,##0.00").format(couponResult!.discountValue ?? 0)}',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
        ),
    ]);
  }
}
