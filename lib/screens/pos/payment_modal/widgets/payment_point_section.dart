import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/customer.dart';
import '../../../../services/settings_service.dart';

class PaymentPointSection extends StatelessWidget {
  final Customer? customer;
  final int pointsToRedeem;
  final double pointDiscountAmount;
  final VoidCallback onOpenRedemptionDialog;

  const PaymentPointSection({
    super.key,
    required this.customer,
    required this.pointsToRedeem,
    required this.pointDiscountAmount,
    required this.onOpenRedemptionDialog,
  });

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final hasPointsEnabled = settings.pointEnabled;
    final isRealCustomer = customer != null && customer!.id != 1;
    final pointsAvailable = customer?.currentPoints ?? 0;
    final pointsUsed = pointsToRedeem;
    final pointDiscount = pointDiscountAmount;

    return Column(
      children: [
        // ปุ่มแลกแต้ม
        if (hasPointsEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OutlinedButton.icon(
              onPressed: isRealCustomer && pointsAvailable > 0
                  ? onOpenRedemptionDialog
                  : () {
                      if (!isRealCustomer) {
                        SnackbarUtils.showLeft(context, 'กรุณาเลือกลูกค้า (มุมขวาบน) ก่อนใช้แต้ม');
                      } else {
                        SnackbarUtils.showLeft(context, 'ลูกค้าท่านนี้ยังไม่มีแต้มเพียงพอ');
                      }
                    },
              icon: Icon(
                  pointsUsed > 0 ? Icons.stars : Icons.stars_outlined,
                  color: (isRealCustomer && pointsAvailable > 0)
                      ? Colors.amber.shade700
                      : Colors.grey),
              label: Text(
                pointsUsed > 0
                    ? 'ใช้ $pointsUsed แต้ม = ลด ฿${NumberFormat('#,##0.00').format(pointDiscount)}'
                    : isRealCustomer
                        ? 'แลกแต้มโดยตรง (ลูกค้ามี ${NumberFormat('#,##0').format(pointsAvailable)} แต้ม)'
                        : 'แลกแต้ม (เฉพาะสมาชิก)',
                style: TextStyle(
                    color: (isRealCustomer && pointsAvailable > 0)
                        ? Colors.amber.shade800
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: (isRealCustomer && pointsAvailable > 0)
                        ? Colors.amber.shade400
                        : Colors.grey.shade400,
                    width: 1.5),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        // ปุ่มแลกของรางวัล (Coming Soon)
        if (hasPointsEnabled && (isRealCustomer && pointsAvailable > 0))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '🕒 ระบบแคตตาล็อกแลกของรางวัลกำลังพัฒนาสำหรับ Line Web-App พบกันเร็วๆ นี้!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              icon: const Icon(Icons.card_giftcard, color: Colors.blueAccent),
              label: const Text(
                'แคตตาล็อกแลกของรางวัล',
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.blue.shade300, width: 1.5),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        // แสดงส่วนลดเมื่อใช้แต้ม
        if (pointsUsed > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text("สวนลดแตม: $pointsUsed แตม",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                Text(
                  "- ${NumberFormat('#,##0.00').format(pointDiscount)}",
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
