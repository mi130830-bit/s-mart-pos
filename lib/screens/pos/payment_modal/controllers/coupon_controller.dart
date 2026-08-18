import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import '../../../../repositories/reward_repository.dart';
import '../../pos_state_manager.dart';

mixin CouponControllerMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController couponCtrl = TextEditingController();
  bool isValidatingCoupon = false;
  CouponValidationResult? couponResult;
  bool couponApplied = false;

  void disposeCouponController() {
    couponCtrl.dispose();
  }

  void clearCoupon(PosStateNotifier posState) {
    setState(() {
      couponApplied = false;
      couponResult = null;
      couponCtrl.clear();
      posState.applyCouponDiscount(0, null);
    });
  }

  Future<void> validateAndApplyCoupon(
      PosStateNotifier posState, VoidCallback onUpdateRemainingAmount) async {
    final code = couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final customer = posState.currentCustomer;
    if (customer == null || customer.id <= 0) {
      SnackbarUtils.showLeft(
          context, 'กรุณาเลือกลูกค้าที่เป็นเจ้าของคูปองก่อนใช้สิทธิ์');
      return;
    }

    setState(() {
      isValidatingCoupon = true;
      couponResult = null;
    });

    final repo = RewardRepository();
    final result = await repo.validateCoupon(code, customerId: customer.id);

    if (!mounted) return;

    setState(() {
      isValidatingCoupon = false;
      couponResult = result;
    });

    if (result.isValid) {
      if ((result.discountValue ?? 0) > posState.pointRedemptionBase) {
        setState(() {
          couponResult = CouponValidationResult.invalid(
              'มูลค่าคูปองสูงกว่ายอดสินค้าหลังส่วนลด จึงใช้กับบิลนี้ไม่ได้');
        });
        return;
      }
      if (posState.pointsToRedeem > 0) {
        posState.clearPointDiscount();
        SnackbarUtils.showLeft(
            context, 'ล้างการแลกแต้มแล้ว เพราะคูปองใช้ร่วมกับแต้มไม่ได้');
      }
      // Auto-apply
      posState.applyCouponDiscount(
          result.discountValue ?? 0, result.couponCode);
      setState(() => couponApplied = true);

      onUpdateRemainingAmount();

      if (mounted) {
        SnackbarUtils.showLeft(context,
            '🎟️ ใช้คูปอง ${result.couponCode} — ลด ฿${result.discountValue?.toStringAsFixed(2)}');
      }
    }
  }
}
